/**
 * `outline`: the definitions in a file, or in every source file under a folder (a small repo
 * map, like Aider's), with line numbers. It lets the model find its way back into a file
 * without reading all of it, which matters once mask.ts has hidden the earlier reads.
 *
 * Definitions are found by per-language regexes (Rust, Go, Python, TS/JS, Nix, shell), not a
 * parser: enough to navigate by, and nothing to install.
 */
import { readdirSync, readFileSync, statSync } from "node:fs";
import { extname, join, relative, resolve } from "node:path";
import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MAX_FILES = 60;
const MAX_CHARS = 8000;
const SKIP = new Set([".git", "target", "node_modules", "vendor", "dist", "build", "__pycache__", ".venv", "result"]);

const DEFS: Record<string, RegExp> = {
	".rs": /^\s*(pub(\([^)]*\))?\s+)?(async\s+)?(fn|struct|enum|trait|impl|type|mod|const|static|macro_rules!)\b/,
	".go": /^(func|type|var|const)\b/,
	".py": /^\s*(async\s+)?(def|class)\s/,
	".ts": /^\s*(export\s+)?(default\s+)?(async\s+)?(function|class|interface|type|enum|const\s+\w+\s*=\s*(async\s*)?\()/,
	".nix": /^\s{0,4}[\w.-]+\s*=\s*(\{|\w+:|rec\s*\{|pkgs\.|lib\.mk)/,
	".sh": /^\s*(function\s+\w+|\w+\s*\(\)\s*\{)/,
};
DEFS[".tsx"] = DEFS[".js"] = DEFS[".mjs"] = DEFS[".ts"];
DEFS[".bash"] = DEFS[".sh"];

function outlineFile(path: string): string[] {
	const re = DEFS[extname(path)];
	if (!re) return [];
	const out: string[] = [];
	readFileSync(path, "utf8")
		.split("\n")
		.forEach((l, i) => {
			if (re.test(l)) out.push(`${String(i + 1).padStart(5)}  ${l.trimEnd().replace(/\s*\{\s*$/, "").slice(0, 160)}`);
		});
	return out;
}

function sourceFiles(dir: string, out: string[] = []): string[] {
	for (const name of readdirSync(dir).sort()) {
		if (out.length >= MAX_FILES) break;
		if (SKIP.has(name) || name.startsWith(".")) continue;
		const p = join(dir, name);
		const st = statSync(p);
		if (st.isDirectory()) sourceFiles(p, out);
		else if (DEFS[extname(name)]) out.push(p);
	}
	return out;
}

const outlineTool = defineTool({
	name: "outline",
	label: "Outline",
	description:
		"List the functions, types and other definitions in a source file with their line numbers, or in every source " +
		"file under a folder (a map of the project). Use it to find where something is, then read just those lines " +
		"with offset/limit instead of reading the whole file.",
	promptSnippet: "outline: definitions in a file or folder, with line numbers",
	parameters: Type.Object({
		path: Type.String({ description: "A source file or a folder (default: the project folder)" }),
	}),
	async execute(_id, params, _signal, _update, ctx) {
		const target = resolve(ctx.cwd, params.path || ".");
		const files = statSync(target).isDirectory() ? sourceFiles(target) : [target];
		const parts: string[] = [];
		for (const f of files) {
			const defs = outlineFile(f);
			const lines = readFileSync(f, "utf8").split("\n").length;
			parts.push(`${relative(ctx.cwd, f) || f} (${lines} lines)${defs.length ? `\n${defs.join("\n")}` : ""}`);
		}
		let text = parts.join("\n\n") || "No source files found.";
		if (files.length >= MAX_FILES) text += `\n\n[Stopped at ${MAX_FILES} files; outline a subfolder for more.]`;
		if (text.length > MAX_CHARS) text = `${text.slice(0, MAX_CHARS)}\n[... cut; outline a single file or subfolder]`;
		return { content: [{ type: "text", text }], details: undefined };
	},
});

export default function (pi: ExtensionAPI) {
	pi.registerTool(outlineTool);
}
