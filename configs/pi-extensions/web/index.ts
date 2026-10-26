/**
 * Web tools for small-context agents; replaces pi-searxng's index.ts (its config.ts and
 * extract.ts deps are reused).
 *
 * - web_search: SearXNG results with short snippets and dates; marks URLs already fetched.
 * - fetch_content: saves the page (Markdown) or file (GitHub blob links go to the raw file)
 *   to disk and returns only an outline with line numbers, a short preview and the path.
 *   The agent then uses grep and read with offset/limit on that file. No repo clones.
 *
 * Refuses non-public addresses (loopback, LAN, Tailscale) so pages can't steer agents at
 * the home network. Files go to $PI_RESEARCH_DIR/pages when set, else $TMPDIR/pi-web
 * (swept after a day).
 */
import { createHash } from "node:crypto";
import { lookup } from "node:dns/promises";
import { appendFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { isIP } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Readability } from "@mozilla/readability";
import { Type } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { parseHTML } from "linkedom";
import TurndownService from "turndown";
import { loadConfig } from "./config.js";

const RUN_DIR = process.env.PI_RESEARCH_DIR;
const PAGES = RUN_DIR ? join(RUN_DIR, "pages") : join(tmpdir(), "pi-web");
const MAX_BYTES = 5 * 1024 * 1024;
const TIMEOUT = 30_000;
const DAY = 24 * 60 * 60 * 1000;
const turndown = new TurndownService({ headingStyle: "atx", codeBlockStyle: "fenced" });

const text = (t: string, details?: unknown) => ({ content: [{ type: "text" as const, text: t }], details });

// --- fetched-URL log, shared by the researchers of one run ---------------------------
const fetchedLog = RUN_DIR ? join(RUN_DIR, "fetched.txt") : undefined;
const localFetched = new Set<string>();
function fetchedUrls(): Set<string> {
	const all = new Set(localFetched);
	if (fetchedLog && existsSync(fetchedLog)) for (const u of readFileSync(fetchedLog, "utf8").split("\n")) if (u) all.add(u);
	return all;
}
function markFetched(url: string) {
	localFetched.add(url);
	if (fetchedLog) appendFileSync(fetchedLog, `${url}\n`);
}

// --- address guard ---------------------------------------------------------------------
function isPrivate(ip: string): boolean {
	if (isIP(ip) === 6) {
		const v = ip.toLowerCase();
		if (v.startsWith("::ffff:")) return isPrivate(v.slice(7));
		return v === "::1" || v === "::" || v.startsWith("fc") || v.startsWith("fd") || v.startsWith("fe8");
	}
	const [a, b] = ip.split(".").map(Number);
	return (
		a === 0 || a === 10 || a === 127 ||
		(a === 100 && b >= 64 && b <= 127) || // CGNAT, incl. Tailscale
		(a === 169 && b === 254) ||
		(a === 172 && b >= 16 && b <= 31) ||
		(a === 192 && b === 168)
	);
}
async function assertPublic(url: URL) {
	if (url.protocol !== "https:" && url.protocol !== "http:") throw new Error(`Only http(s) URLs: ${url.protocol}`);
	const host = url.hostname.replace(/^\[|\]$/g, "");
	const addrs = isIP(host) ? [{ address: host }] : await lookup(host, { all: true });
	if (!addrs.length || addrs.some((a) => isPrivate(a.address))) throw new Error(`Refusing non-public address: ${url.hostname}`);
}

// --- GitHub links ------------------------------------------------------------------------
/** github.com/o/r/blob/ref/path -> raw file; repo or tree pages -> raw README + hint. */
function githubTarget(url: URL): { raw: string; title: string; hint?: string } | undefined {
	if (url.hostname !== "github.com") return;
	const [owner, repo, kind, ref, ...rest] = url.pathname.split("/").filter(Boolean);
	if (!owner || !repo) return;
	if (kind === "blob" && ref && rest.length)
		return { raw: `https://raw.githubusercontent.com/${owner}/${repo}/${ref}/${rest.join("/")}`, title: `${owner}/${repo}: ${rest.join("/")}` };
	if (!kind || kind === "tree")
		return {
			raw: `https://raw.githubusercontent.com/${owner}/${repo}/${ref ?? "HEAD"}/README.md`,
			title: `${owner}/${repo} README`,
			hint: `This is the README of ${owner}/${repo}. To find code in it, use code search with repo "${owner}/${repo}", then fetch the github.com/.../blob/... links it returns.`,
		};
}

// --- outline -------------------------------------------------------------------------------
const CODE_DEF = /^\s*(export\s+)?(pub\s+)?(async\s+)?(func|fn|def|class|interface|type|struct|enum|impl|function|const\s+\w+\s*=\s*\(|package|module)\b/;
function outline(lines: string[], markdown: boolean): string {
	const out: string[] = [];
	let inFence = false;
	lines.forEach((line, i) => {
		if (markdown && line.startsWith("```")) inFence = !inFence;
		const hit = markdown ? !inFence && /^#{1,4} \S/.test(line) : CODE_DEF.test(line);
		if (hit && out.length < 40) out.push(`L${i + 1}: ${line.trim().slice(0, 100)}`);
	});
	return out.length ? out.join("\n") : "(no headings)";
}

async function getPage(target: string, hops = 0): Promise<{ title: string; body: string; markdown: boolean }> {
	if (hops > 5) throw new Error("Too many redirects");
	const url = new URL(target);
	await assertPublic(url);
	const controller = new AbortController();
	const timer = setTimeout(() => controller.abort(), TIMEOUT);
	try {
		const res = await fetch(url, {
			signal: controller.signal,
			redirect: "manual",
			headers: {
				"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
				Accept: "text/html,application/xhtml+xml,text/plain,*/*;q=0.8",
			},
		});
		if (res.status >= 300 && res.status < 400 && res.headers.get("location")) {
			// Follow redirects ourselves so each hop passes the address guard.
			return getPage(new URL(res.headers.get("location")!, url).toString(), hops + 1);
		}
		if (!res.ok) throw new Error(`HTTP ${res.status}`);
		if (Number(res.headers.get("content-length")) > MAX_BYTES) throw new Error("Too large (> 5 MB)");
		const type = res.headers.get("content-type") ?? "";
		if (type.includes("pdf")) throw new Error("PDF pages aren't supported yet; look for an HTML version");
		const raw = await res.text();
		if (raw.length > MAX_BYTES) throw new Error("Too large (> 5 MB)");
		if (!type.includes("html")) {
			const md = /\.(md|markdown|mdx)$/i.test(url.pathname);
			return { title: url.pathname.split("/").pop() || url.hostname, body: raw, markdown: md };
		}
		const { document } = parseHTML(raw);
		const article = new Readability(document).parse();
		if (!article?.content) throw new Error("Could not extract the page's text");
		return { title: article.title || url.hostname, body: turndown.turndown(article.content), markdown: true };
	} finally {
		clearTimeout(timer);
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", () => {
		if (RUN_DIR) return;
		try {
			for (const f of readdirSync(PAGES)) {
				const p = join(PAGES, f);
				if (Date.now() - statSync(p).mtimeMs > DAY) rmSync(p, { force: true });
			}
		} catch {
			/* nothing to clean */
		}
	});

	pi.registerTool({
		name: "web_search",
		label: "Web Search",
		description:
			"Search the web (SearXNG). Returns titles, URLs, dates and short snippets. Read the snippets first and only fetch the most promising 1-3 results.",
		parameters: Type.Object({
			query: Type.String({ description: "Search query; add a year or 'latest' for current info" }),
			limit: Type.Optional(Type.Number({ description: "Max results (default 8)" })),
		}),
		async execute(_id, params, signal) {
			const config = loadConfig();
			const url = new URL(`${config.searxngUrl}/search`);
			url.searchParams.set("q", params.query);
			url.searchParams.set("format", "json");
			const res = await fetch(url, { signal, headers: { Accept: "application/json" } });
			if (!res.ok) throw new Error(`SearXNG returned ${res.status}`);
			const data: any = await res.json();
			const seen = fetchedUrls();
			const results = (data.results ?? []).slice(0, Math.min(params.limit ?? 8, 10));
			if (!results.length) return text("No results.", { count: 0 });
			const lines = results.map((r: any, i: number) => {
				const date = r.publishedDate ? ` (${String(r.publishedDate).slice(0, 10)})` : "";
				const mark = seen.has(r.url) ? " [already fetched]" : "";
				const snippet = String(r.content ?? "").replace(/\s+/g, " ").slice(0, 240);
				return `${i + 1}. ${r.title ?? "Untitled"}${date}${mark}\n   ${r.url}\n   ${snippet}`;
			});
			return text(lines.join("\n"), { count: results.length });
		},
	});

	pi.registerTool({
		name: "fetch_content",
		label: "Fetch",
		description:
			"Fetch a web page or GitHub file and save it to a local file. Returns an outline with line numbers, a short preview and the file path; " +
			"then use grep on the path to find what you need and read with offset/limit around it. GitHub blob links are fetched as raw files.",
		parameters: Type.Object({ url: Type.String({ description: "URL to fetch" }) }),
		async execute(_id, params) {
			const gh = githubTarget(new URL(params.url));
			const target = gh?.raw ?? params.url;
			const file = join(PAGES, `${createHash("sha256").update(target).digest("hex").slice(0, 12)}.md`);
			let body: string;
			let title: string;
			let markdown: boolean;
			if (existsSync(file) && Date.now() - statSync(file).mtimeMs < DAY) {
				const saved = readFileSync(file, "utf8");
				[title, body] = [saved.split("\n", 2)[1]?.replace(/^# /, "") ?? "", saved];
				markdown = true;
			} else {
				const page = await getPage(target);
				({ title, markdown } = page);
				if (gh) title = gh.title;
				body = `<!-- source: ${params.url} | fetched: ${new Date().toISOString().slice(0, 10)} -->\n# ${title}\n\n${page.body}`;
				mkdirSync(PAGES, { recursive: true, mode: 0o700 });
				writeFileSync(file, body, { mode: 0o600 });
			}
			markFetched(params.url);
			const lines = body.split("\n");
			const preview = lines.slice(2).join("\n").trim().slice(0, 700);
			return text(
				[
					`Saved: ${file}`,
					`Title: ${title}`,
					`Size: ${lines.length} lines, ${body.length} chars`,
					...(gh?.hint ? [`Note: ${gh.hint}`] : []),
					`Outline:\n${outline(lines, markdown)}`,
					`Preview:\n${preview}`,
					`Next: grep this file for your terms, then read it with offset/limit around the matches.`,
				].join("\n\n"),
				{ file, url: params.url, chars: body.length },
			);
		},
	});
}
