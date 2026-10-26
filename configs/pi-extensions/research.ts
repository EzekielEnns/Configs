/**
 * Tools for research sub-agents, only loaded when PI_RESEARCH_DIR is set (the subagent
 * extension sets it), so ordinary sessions don't pay context for them:
 * - `note`: save each finding as it goes to $PI_RESEARCH_DIR/findings.jsonl, so a run that
 *   dies or runs out of context still leaves results.
 * - `code_search`: grep.app's public GitHub code search (no login, public repos only;
 *   queries go to Vercel, so never search for private code). We call its MCP endpoint
 *   ourselves rather than exposing its tool: small models put "language:Go" in the query
 *   and get nothing, and its full results are ~3k tokens. This fixes up the query, saves
 *   the full results next to the fetched pages and returns a short list.
 */
import { createHash } from "node:crypto";
import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const DIR = process.env.PI_RESEARCH_DIR;
const AGENT = process.env.PI_AGENT_NAME || "agent";
const GREP_APP = "https://mcp.grep.app";

const noteTool = defineTool({
	name: "note",
	label: "Note",
	description:
		"Save one finding for the final answer. Call it as soon as you confirm something, one fact per call. " +
		"Notes survive even if you run out of context.",
	parameters: Type.Object({
		claim: Type.String({ description: "The finding, one sentence" }),
		url: Type.String({ description: "Source URL" }),
		quote: Type.Optional(Type.String({ description: "Short exact quote from the source that supports it" })),
		date: Type.Optional(Type.String({ description: "Date or version of the source, if known" })),
	}),
	async execute(_id, params) {
		mkdirSync(DIR!, { recursive: true });
		const entry = { agent: AGENT, time: new Date().toISOString(), ...params };
		appendFileSync(join(DIR!, "findings.jsonl"), `${JSON.stringify(entry)}\n`);
		return { content: [{ type: "text", text: "Saved." }], details: undefined };
	},
});

// grep.app's language names; models write them in any case.
const LANGUAGES: Record<string, string> = {
	go: "Go", golang: "Go", python: "Python", py: "Python", typescript: "TypeScript", ts: "TypeScript",
	tsx: "TSX", javascript: "JavaScript", js: "JavaScript", rust: "Rust", java: "Java", c: "C",
	"c++": "C++", cpp: "C++", "c#": "C#", csharp: "C#", nix: "Nix", lua: "Lua", ruby: "Ruby",
	kotlin: "Kotlin", swift: "Swift", zig: "Zig", markdown: "Markdown", yaml: "YAML", shell: "Shell",
};

const codeSearchTool = defineTool({
	name: "code_search",
	label: "Code search",
	description:
		"Search public GitHub code for a literal code pattern, like grep across a million repos. " +
		"Use code that appears in files (e.g. `mcp.AddTool(`), not keywords or questions. " +
		"Returns repo, path, line and a short snippet per match; fetch_content the URL to see the whole file.",
	parameters: Type.Object({
		pattern: Type.String({ description: "Literal code to find, e.g. `http.HandleFunc(`" }),
		language: Type.Optional(Type.String({ description: "Language, e.g. Go, Python, TypeScript" })),
		repo: Type.Optional(Type.String({ description: "Limit to a repo or org, e.g. `golang/go` or `vercel/`" })),
		path: Type.Optional(Type.String({ description: "Limit to paths containing this, e.g. `_test.go`" })),
	}),
	async execute(_id, params, signal) {
		// Move "language:Go" / "repo:x/y" / "lang:go" out of the pattern into the filters.
		let query = params.pattern;
		let language = params.language;
		let repo = params.repo;
		query = query.replace(/\b(?:language|lang):(\S+)/gi, (_, l) => ((language ??= l), "")).trim();
		query = query.replace(/\brepo:(\S+)/gi, (_, r) => ((repo ??= r), "")).trim();
		const args: Record<string, unknown> = { query };
		if (language) args.language = [LANGUAGES[language.toLowerCase()] ?? language];
		if (repo) args.repo = repo;
		if (params.path) args.path = params.path;

		const res = await fetch(GREP_APP, {
			method: "POST",
			signal,
			headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
			body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "searchGitHub", arguments: args } }),
		});
		if (!res.ok) throw new Error(`grep.app returned ${res.status}`);
		const raw = await res.text();
		const data = JSON.parse(raw.match(/^data: (.*)$/m)?.[1] ?? raw);
		if (data.error) throw new Error(data.error.message);
		const results: string[] = (data.result?.content ?? []).map((c: { text: string }) => c.text);
		const found = results.filter((r) => r.startsWith("Repository:"));
		if (!found.length) {
			return {
				content: [{ type: "text", text: `No matches for \`${query}\`${language ? ` in ${args.language}` : ""}. Try a shorter literal pattern.` }],
				details: undefined,
			};
		}

		const pages = join(DIR!, "pages");
		mkdirSync(pages, { recursive: true });
		const file = join(pages, `code-${createHash("sha256").update(JSON.stringify(args)).digest("hex").slice(0, 12)}.md`);
		writeFileSync(file, found.join("\n\n"));

		const short = found.slice(0, 6).map((r, i) => {
			const field = (name: string) => r.match(new RegExp(`^${name}: (.*)$`, "m"))?.[1] ?? "";
			const line = r.match(/--- Snippet 1 \(Line (\d+)\) ---/)?.[1];
			const snippet = (r.split(/--- Snippet 1 \(Line \d+\) ---\n/)[1] ?? "").split("\n--- Snippet")[0];
			const lines = snippet.split("\n").filter((l) => l.trim()).slice(0, 6).join("\n");
			return `${i + 1}. ${field("Repository")} ${field("Path")}${line ? ` (line ${line})` : ""}\n   ${field("URL")}\n${lines}`;
		});
		return {
			content: [
				{
					type: "text",
					text: `${short.join("\n\n")}\n\n[${found.length} matches; all snippets saved to ${file}]`,
				},
			],
			details: undefined,
		};
	},
});

export default function (pi: ExtensionAPI) {
	if (!DIR) return;
	pi.registerTool(noteTool);
	pi.registerTool(codeSearchTool);
}
