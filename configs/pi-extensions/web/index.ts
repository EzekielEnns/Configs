/**
 * Web tools for small-context agents; replaces pi-searxng's index.ts (its config.ts and
 * extract.ts deps are reused).
 *
 * - web_search: results with short snippets and dates from the first provider in
 *   `searchChain` that answers (steps/search.ts); marks URLs already fetched.
 * - fetch_content: saves the page (Markdown) or file (GitHub blob links go to the raw file)
 *   to disk. With a `question`, returns the passages that answer it; without, an outline
 *   with line numbers, a short preview and the path for grep and read. No repo clones.
 * - lookup: search, fetch the top pages in parallel and return the passages that answer
 *   the question, in one call. For quick questions (/lookup).
 * - dig: for each angle of a research question, search, rank the results (Jev, primary
 *   sources first), fetch the best readable pages (a failed or empty page is replaced by the
 *   next result), and have a reader model (Flint, one direct call per page, claims JSON
 *   schema) list the facts in each page's passages; only claims whose quote is found on the
 *   saved page come back (/research-dig). The pi-orch pattern: a script finds and checks,
 *   the model only reads.
 *
 * Passages: BM25 picks them (steps/rank.ts); with PI_EVIDENCE_URL set, BM25's top chunks go
 * to Open Provence on the evidence service, which reranks them and keeps only the sentences
 * that answer the question (steps/prune.ts).
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
import { chunk } from "./steps/chunk.js";
import { CANDIDATES, EVIDENCE_URL, prune } from "./steps/prune.js";
import { rank, type Scored } from "./steps/rank.js";
import { type Result, search, type SearchConfig } from "./steps/search.js";
import { runStep, trace } from "./steps/step.js";

const RUN_DIR = process.env.PI_RESEARCH_DIR;
const PAGES = RUN_DIR ? join(RUN_DIR, "pages") : join(tmpdir(), "pi-web");
const MAX_BYTES = 5 * 1024 * 1024;
const TIMEOUT = 30_000;
const DAY = 24 * 60 * 60 * 1000;
const turndown = new TurndownService({ headingStyle: "atx", codeBlockStyle: "fenced" });
// dig's reader: one chat call per page through the gateway, at most READER_SLOTS at once
// (Flint's llama.cpp slots).
const READER_URL = process.env.PI_READER_GATEWAY ?? "http://desktop:4000/v1";
const READER_MODEL = process.env.PI_READER_MODEL ?? "flint";
const READER_SLOTS = Number(process.env.PI_READER_SLOTS) || 3;
const READER_TIMEOUT = 150_000;
// dig ranks search results before fetching: Jev (a decision model on OpenRouter, through the
// gateway's pass-through, which adds the key) scores each one; a plain rule if it fails.
const JEV_URL = process.env.PI_DIG_JEV_URL ?? "http://desktop:4000/openrouter/decisions";
const JEV_MODEL = process.env.PI_DIG_JEV_MODEL ?? "typesafe/jev-1.14";
const JEV_TIMEOUT = 8_000;
const MIN_PAGE = 800; // chars of text: shorter is a login wall, an error page or a stub

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

interface Saved {
	file: string;
	title: string;
	body: string;
	markdown: boolean;
	hint?: string;
}

/** Fetch a URL (or reuse today's copy) and save it as Markdown under PAGES. */
async function savePage(pageUrl: string): Promise<Saved> {
	const gh = githubTarget(new URL(pageUrl));
	const target = gh?.raw ?? pageUrl;
	const file = join(PAGES, `${createHash("sha256").update(target).digest("hex").slice(0, 12)}.md`);
	if (existsSync(file) && Date.now() - statSync(file).mtimeMs < DAY) {
		const body = readFileSync(file, "utf8");
		return { file, title: body.split("\n", 2)[1]?.replace(/^# /, "") ?? "", body, markdown: true, hint: gh?.hint };
	}
	const page = await getPage(target);
	const title = gh?.title ?? page.title;
	const body = `<!-- source: ${pageUrl} | fetched: ${new Date().toISOString().slice(0, 10)} -->\n# ${title}\n\n${page.body}`;
	mkdirSync(PAGES, { recursive: true, mode: 0o700 });
	writeFileSync(file, body, { mode: 0o600 });
	return { file, title, body, markdown: page.markdown, hint: gh?.hint };
}

/** The passages of a saved page that answer `question`, with line numbers. Passages in
 * `seen` (same text from another copy of the page, e.g. a mirror) are skipped. */
async function passages(
	question: string,
	page: Saved,
	top: number,
	maxChars: number,
	seen = new Set<string>(),
): Promise<{ text: string; picked: Scored[] }> {
	const key = (c: Scored) => c.text.replace(/\W+/g, "").slice(0, 160);
	const chunks = chunk(page.body);
	const bm25 = () => rank(question, chunks, top);
	const ranked = EVIDENCE_URL
		? await runStep(
				"prune",
				15_000,
				(signal) => prune(question, rank(question, chunks, CANDIDATES), top, signal),
				bm25,
				(out) => ({ kept: out.length, best: out.reduce((m, c) => Math.max(m, c.score), 0) }),
			)
		: bm25();
	const picked = ranked.filter((c) => !seen.has(key(c)));
	for (const c of picked) seen.add(key(c));
	let used = 0;
	const parts: string[] = [];
	for (const c of picked) {
		const room = maxChars - used;
		if (room < 200) break;
		const body = c.text.length > room ? `${c.text.slice(0, room)} [...]` : c.text;
		used += body.length;
		parts.push(`[L${c.startLine}-${c.endLine}${c.heading ? ` · ${c.heading}` : ""}]\n${body}`);
	}
	return { text: parts.join("\n\n"), picked };
}

// --- dig: reader calls and quote checks ----------------------------------------------------
const CLAIMS_SCHEMA = {
	type: "object",
	properties: {
		claims: {
			type: "array",
			items: {
				type: "object",
				properties: { claim: { type: "string" }, quote: { type: "string" }, date: { type: "string" } },
				required: ["claim", "quote"],
			},
		},
	},
	required: ["claims"],
};
const READER_PROMPT =
	"You read passages from one web page for a research question and list the facts in them that bear on it " +
	"(on the whole question or on the angle the page was found for: both count), " +
	"as claims. Each claim states one fact in one sentence, as the fact itself (\"X supports Y\", not \"the page states that X supports Y\"), with a quote copied exactly from the passages (a phrase " +
	"or sentence, at least a few words, not changed or joined from two places) and, if the page states it, the " +
	"date or version it applies to. Give one claim for every relevant fact: names, versions, dates, numbers, " +
	"links or commands, what is recommended, required or deprecated. Don't add what you know but the page " +
	"doesn't say. If nothing bears on the question, reply {\"claims\": []}. Reply with only the JSON. " +
	"Think briefly: don't draft the claims while thinking; write them only in the JSON answer.";

let readersBusy = 0;
const readerQueue: (() => void)[] = [];
async function readerSlot<T>(fn: () => Promise<T>): Promise<T> {
	if (readersBusy >= READER_SLOTS) await new Promise<void>((r) => readerQueue.push(r));
	readersBusy++;
	try {
		return await fn();
	} finally {
		readersBusy--;
		readerQueue.shift()?.();
	}
}

interface Claim {
	claim: string;
	quote: string;
	date?: string;
}

async function readPage(
	question: string,
	angle: string,
	today: string,
	url: string,
	title: string,
	found: string,
): Promise<Claim[]> {
	const ask = async (schema: boolean) => {
		const body = {
			model: READER_MODEL,
			max_tokens: 8192,
			messages: [
				{ role: "system", content: READER_PROMPT },
				{
					role: "user",
					content:
						`Today is ${today}. Research question: ${question}\nThis page was found for the angle: ${angle}\n\n` +
						`Page: ${title}\n${url}\n\nPassages ([L..] marks where each is on the page):\n\n${found}`,
				},
			],
			...(schema ? { response_format: { type: "json_schema", json_schema: { name: "claims", schema: CLAIMS_SCHEMA } } } : {}),
		};
		const res = await fetch(`${READER_URL}/chat/completions`, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify(body),
			signal: AbortSignal.timeout(READER_TIMEOUT),
		});
		if (!res.ok) throw new Error(`reader HTTP ${res.status}`);
		const data = (await res.json()) as { choices: { message: { content?: string; reasoning_content?: string } }[] };
		const msg = data.choices?.[0]?.message ?? {};
		const reply = msg.content ?? "";
		const parsed = JSON.parse(reply.slice(reply.indexOf("{"), reply.lastIndexOf("}") + 1)) as { claims?: Claim[] };
		const claims = (parsed.claims ?? []).filter((c) => c && typeof c.claim === "string" && typeof c.quote === "string");
		return { claims, cut: (msg.reasoning_content ?? "").includes("Thinking budget reached") };
	};
	// Flint sometimes drafts the claims while thinking, hits its thinking budget, and the
	// schema-held answer then comes out empty (eval: 3 relevant pages, 0 claims). Once more
	// without the schema in that case; the reply is still parsed as JSON.
	const first = await ask(true);
	if (first.claims.length || !first.cut) return first.claims;
	trace({ step: "reread", ms: 0, ok: true, url });
	return (await ask(false).catch(() => first)).claims;
}

const RANK_LEVELS = [
	"Unrelated, or a page that won't hold the answer (SEO farm, aggregator, forum chatter off the topic).",
	"A related secondary source (blog, tutorial, news) that may answer part of it.",
	"A good source that directly answers part of it, or a primary source on a neighbouring part.",
	"A primary source (official docs, spec, release notes, source repo, the vendor's or project's own page) that directly answers it and looks current.",
];

/** 0-4: Jev's level for a search result plus its yes-probability that it's a primary source that answers. */
async function jevScore(question: string, angle: string, today: string, r: Result): Promise<number> {
	const body = {
		model: JEV_MODEL,
		state: [
			`Today is ${today}. Research question: ${question}\nAngle being searched: ${angle}`,
			`Search result:\nTitle: ${r.title}\nURL: ${r.url}${r.date ? `\nDate: ${r.date}` : ""}\nSnippet: ${r.snippet.slice(0, 400)}`,
		],
		questions: {
			rel: { type: "score", instructions: "How good is this result to read for the angle?", criteria: RANK_LEVELS },
			primary: { type: "noul", instructions: "This result is a primary source that directly answers the angle." },
		},
	};
	const res = await fetch(JEV_URL, {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify(body),
		signal: AbortSignal.timeout(JEV_TIMEOUT),
	});
	if (!res.ok) throw new Error(`jev HTTP ${res.status}`);
	const ans = ((await res.json()) as { answers: Record<string, { score?: number; noul?: number }> }).answers;
	return Number(ans.rel.score) + Number(ans.primary.noul);
}

/** Without Jev: primary-looking hosts first, then search order. */
function ruleScore(r: Result): number {
	let u: URL;
	try {
		u = new URL(r.url);
	} catch {
		return -1;
	}
	const host = u.hostname.replace(/^www\./, "");
	let s = 0;
	if (/^(docs|developer|developers|learn|api|spec|specs)\./.test(host) || host === "github.com") s += 2;
	if (/\/(docs|spec|specification|reference|releases|changelog)(\/|$)/i.test(u.pathname)) s += 1;
	if (/(^|\.)(reddit|quora|medium|linkedin|youtube|pinterest|facebook)\.com$/.test(host)) s -= 1;
	return s;
}

/** Candidates best first, and how they were ranked. */
async function rankResults(question: string, angle: string, today: string, rs: Result[]): Promise<{ order: Result[]; by: string }> {
	const start = Date.now();
	const scores = await Promise.all(rs.map((r) => jevScore(question, angle, today, r).catch(() => undefined)));
	const ok = scores.filter((s) => s !== undefined).length;
	const by = ok >= Math.ceil(rs.length / 2) ? "jev" : "rule";
	const keyed = rs.map((r, i) => ({ r, i, s: by === "jev" ? (scores[i] ?? ruleScore(r) / 2) : ruleScore(r) }));
	keyed.sort((a, b) => b.s - a.s || a.i - b.i);
	trace({ step: "rank", ms: Date.now() - start, ok: true, by, candidates: rs.length, scored: ok, top: keyed[0]?.r.url });
	return { order: keyed.map((k) => k.r), by };
}

/** Text for quote matching: link targets, Markdown marks, case and spacing don't count. */
function plain(s: string): string {
	return s
		.replace(/\]\([^)]*\)/g, "]")
		.replace(/[*_`#>[\]|]/g, " ")
		.replace(/[‘’]/g, "'")
		.replace(/[“”]/g, '"')
		.replace(/\s+/g, " ")
		.trim()
		.toLowerCase();
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
			"Search the web. Returns titles, URLs, dates and short snippets. Read the snippets first and only fetch the most promising 1-3 results.",
		parameters: Type.Object({
			query: Type.String({ description: "Search query; add a year or 'latest' for current info" }),
			limit: Type.Optional(Type.Number({ description: "Max results (default 8)" })),
		}),
		async execute(_id, params) {
			const results = await search(loadConfig() as SearchConfig, params.query, Math.min(params.limit ?? 8, 10));
			if (!results.length) return text("No results.", { count: 0 });
			const seen = fetchedUrls();
			const lines = results.map((r, i) => {
				const date = r.date ? ` (${r.date})` : "";
				const mark = seen.has(r.url) ? " [already fetched]" : "";
				return `${i + 1}. ${r.title}${date}${mark}\n   ${r.url}\n   ${r.snippet.slice(0, 240)}`;
			});
			return text(lines.join("\n"), { count: results.length, source: results[0].source });
		},
	});

	pi.registerTool({
		name: "fetch_content",
		label: "Fetch",
		description:
			"Fetch a web page or GitHub file and save it to a local file. Pass `question` to get back the passages that answer it. " +
			"Without it, returns an outline with line numbers, a short preview and the file path; then grep the path and read with offset/limit. " +
			"GitHub blob links are fetched as raw files.",
		parameters: Type.Object({
			url: Type.String({ description: "URL to fetch" }),
			question: Type.Optional(
				Type.String({ description: "What you want from the page; returns the passages that answer it instead of an outline" }),
			),
		}),
		async execute(_id, params) {
			const page = await savePage(params.url);
			markFetched(params.url);
			const lines = page.body.split("\n");
			const head = [`Saved: ${page.file}`, `Title: ${page.title}`, `Size: ${lines.length} lines, ${page.body.length} chars`];
			if (page.hint) head.push(`Note: ${page.hint}`);
			if (params.question) {
				const { text: found, picked } = await passages(params.question, page, 4, 4000);
				if (picked.length)
					return text(
						[...head, `Passages for "${params.question}":\n\n${found}`, "Need more? read the file with offset/limit around these lines, or grep it."].join("\n\n"),
						{ file: page.file, url: params.url, chars: page.body.length, passages: picked.length },
					);
				head.push("No passage matched the question's words; outline below.");
			}
			const preview = lines.slice(2).join("\n").trim().slice(0, 700);
			return text(
				[
					...head,
					`Outline:\n${outline(lines, page.markdown)}`,
					`Preview:\n${preview}`,
					`Next: grep this file for your terms, then read it with offset/limit around the matches.`,
				].join("\n\n"),
				{ file: page.file, url: params.url, chars: page.body.length },
			);
		},
	});

	pi.registerTool({
		name: "lookup",
		label: "Lookup",
		description:
			"Answer a quick question from the web in one call: searches, fetches the top pages and returns the passages that answer the question, with URLs. " +
			"Use a focused search query (add the year for anything current). Call again with a different query if the passages don't answer it.",
		parameters: Type.Object({
			question: Type.String({ description: "The question, in full" }),
			query: Type.Optional(Type.String({ description: "Search query, if different from the question" })),
			pages: Type.Optional(Type.Number({ description: "Pages to read (default 3, max 5)" })),
		}),
		async execute(_id, params) {
			const query = params.query ?? params.question;
			const results = await search(loadConfig() as SearchConfig, query, 8);
			if (!results.length) return text(`No search results for "${query}". Try a different query.`, { pages: 0 });
			const n = Math.min(Math.max(params.pages ?? 3, 1), 5);
			const pages = await Promise.all(
				results.slice(0, n).map((r) =>
					runStep(
						"fetch",
						20_000,
						() => savePage(r.url),
						() => undefined,
						(p) => ({ url: r.url, chars: p?.body.length ?? 0 }),
					).then((page) => ({ r, page })),
				),
			);
			const blocks: string[] = [];
			const seen = new Set<string>();
			for (const { r, page } of pages) {
				const date = r.date ? ` (${r.date})` : "";
				if (!page) {
					blocks.push(`## ${r.title}${date}\n${r.url}\n(couldn't fetch; search snippet: ${r.snippet.slice(0, 300)})`);
					continue;
				}
				markFetched(r.url);
				const { text: found } = await passages(params.question, page, 2, 2000, seen);
				const none = `(no new passage: it matches an earlier page or not the question; snippet: ${r.snippet.slice(0, 300)})`;
				blocks.push(`## ${page.title || r.title}${date}\n${r.url} · saved: ${page.file}\n\n${found || none}`);
			}
			const more = results.slice(n).map((r) => `- ${r.title}: ${r.url}`);
			return text(
				[`Results for "${query}":`, ...blocks, ...(more.length ? [`Other results (not read):\n${more.join("\n")}`] : [])].join("\n\n"),
				{ pages: pages.filter((p) => p.page).length, source: results[0].source },
			);
		},
	});

	pi.registerTool({
		name: "dig",
		label: "Dig",
		description:
			"Research angles of a question in one call. For each angle: searches its queries, ranks the results (primary sources " +
			"first), fetches the best readable pages, and a reader model lists the facts in each; only facts whose quote is found " +
			"on the page come back, with URLs. Put all angles in one call: they run at the same time.",
		parameters: Type.Object({
			today: Type.String({ description: "Today's date, YYYY-MM-DD" }),
			question: Type.String({ description: "The whole research question, as asked" }),
			angles: Type.Array(
				Type.Object({
					question: Type.String({ description: "What this angle must answer, in full" }),
					queries: Type.Array(Type.String(), { description: "1-3 search queries; add the year or 'latest' for current info" }),
				}),
				{ description: "1-3 angles that don't overlap" },
			),
			pages: Type.Optional(Type.Number({ description: "Pages to read per angle (default 3, max 5)" })),
		}),
		async execute(_id, params) {
			const n = Math.min(Math.max(params.pages ?? 3, 1), 5);
			const whole = params.question;
			const seenPages = fetchedUrls();
			const taken = new Set<string>();
			const out = await Promise.all(
				params.angles.slice(0, 3).map(async (angle) => {
					// Results of all its queries, interleaved, minus pages already tried in this run.
					const lists = await Promise.all(
						angle.queries.slice(0, 3).map((q) => search(loadConfig() as SearchConfig, q, 8).catch(() => [] as Result[])),
					);
					const picks: Result[] = [];
					for (let i = 0; i < 8; i++)
						for (const list of lists) {
							const r = list[i];
							if (r && !seenPages.has(r.url) && !picks.some((p) => p.url === r.url)) picks.push(r);
						}
					const { order, by } = await rankResults(whole, angle.question, params.today, picks.slice(0, 12));
					type Read = { r: Result; title: string; claims: Claim[]; dropped: number };
					type Skip = { r: Result; why: string; fetchFailed: boolean };
					const reads: Read[] = [];
					const skipped: Skip[] = [];
					let next = 0;
					let empty = 0; // fetched but nothing to read: these cost time, failed fetches don't
					// n lanes; each takes the next ranked result until it has read one page (back-fill).
					const lane = async () => {
						while (next < order.length && empty <= n) {
							const r = order[next++];
							if (taken.has(r.url)) continue;
							taken.add(r.url);
							const page = await runStep("fetch", 20_000, () => savePage(r.url), () => undefined,
								(p) => ({ url: r.url, chars: p?.body.length ?? 0 }));
							markFetched(r.url); // tried: a second dig call won't pick it again, readable or not
							if (!page) {
								skipped.push({ r, why: "couldn't fetch", fetchFailed: true });
								continue;
							}
							if (page.body.split("\n").slice(2).join("\n").trim().length < MIN_PAGE) {
								skipped.push({ r, why: "page too short (login wall or stub)", fetchFailed: true });
								continue;
							}
							const { text: found, picked } = await passages(`${angle.question} ${whole}`, page, 6, 6000);
							if (!picked.length) {
								empty++;
								skipped.push({ r, why: "no passage on the question", fetchFailed: false });
								continue;
							}
							const start = Date.now();
							try {
								const claims = await readerSlot(() =>
									readPage(whole, angle.question, params.today, r.url, page.title || r.title, found));
								const body = plain(page.body);
								const ok = claims.filter((c) => plain(c.quote).length >= 12 && body.includes(plain(c.quote)));
								trace({ step: "read", ms: Date.now() - start, ok: true, url: r.url, claims: claims.length, verified: ok.length });
								if (RUN_DIR && ok.length) {
									mkdirSync(RUN_DIR, { recursive: true });
									for (const c of ok)
										appendFileSync(join(RUN_DIR, "findings.jsonl"),
											`${JSON.stringify({ agent: "dig", time: new Date().toISOString(), claim: c.claim, url: r.url, quote: c.quote, date: c.date ?? r.date })}\n`);
								}
								reads.push({ r, title: page.title || r.title, claims: ok, dropped: claims.length - ok.length });
								return;
							} catch (e) {
								trace({ step: "read", ms: Date.now() - start, ok: false, url: r.url, error: String(e).slice(0, 200) });
								skipped.push({ r, why: `reader failed: ${String(e).slice(0, 80)}`, fetchFailed: false });
							}
						}
					};
					await Promise.all(Array.from({ length: n }, lane));
					trace({ step: "dig-angle", ms: 0, ok: true, by, read: reads.length, skipped: skipped.length,
						backfilled: Math.max(0, reads.length + skipped.length - n) });
					const blocks = reads.map((p) => {
						const date = p.r.date ? ` (${p.r.date})` : "";
						const lines = p.claims.map((c) => `- ${c.claim}${c.date ? ` [${c.date}]` : ""}`);
						return `### ${p.title}${date}\n${p.r.url}\n${lines.join("\n") || "- (nothing on the question)"}` +
							(p.dropped ? `\n(${p.dropped} claims dropped: quote not on the page)` : "");
					});
					// Pages we couldn't read: only their search snippet, which nobody checked.
					const unread = skipped.filter((s) => s.fetchFailed).map((s) =>
						`- ${s.r.title}: ${s.r.url} (${s.why}; unverified search snippet: ${s.r.snippet.slice(0, 200)})`);
					const tried = new Set([...reads.map((p) => p.r.url), ...skipped.map((s) => s.r.url)]);
					const rest = order.filter((r) => !tried.has(r.url)).slice(0, 4).map((r) => `- ${r.title}: ${r.url}`);
					const verified = reads.reduce((s, p) => s + p.claims.length, 0);
					const dropped = reads.reduce((s, p) => s + p.dropped, 0);
					return {
						verified,
						dropped,
						text: [
							`## ${angle.question}`,
							...blocks,
							...(unread.length ? [`Couldn't read (not facts; snippets are unverified):\n${unread.join("\n")}`] : []),
							...(rest.length ? [`Not read:\n${rest.join("\n")}`] : []),
						].join("\n\n"),
					};
				}),
			);
			const verified = out.reduce((s, a) => s + a.verified, 0);
			const dropped = out.reduce((s, a) => s + a.dropped, 0);
			return text(
				[`Facts whose quote was found on the page (${verified} kept, ${dropped} dropped):`, ...out.map((a) => a.text)].join("\n\n"),
				{ verified, dropped },
			);
		},
	});
}
