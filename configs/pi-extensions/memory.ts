/**
 * Memory across sessions, like Claude Code's: one file per fact plus a MEMORY.md index, and
 * the index is in every session's system prompt so the model knows what it can look up.
 *
 * - `~/.pi/memory/` holds facts for every project (who the user is, how they like to work);
 *   `~/.pi/memory/projects/<folder>/` holds facts for the project Pi was started in (and its
 *   subfolders). Each fact is `<name>.md` with name/description/type frontmatter.
 * - before_agent_start: both indexes (capped, so a 32k model keeps its room) and the rules
 *   for using them go at the end of the system prompt. The model reads a fact with `read`
 *   when the index line looks relevant.
 * - `memory` tool: save (create or replace) or forget a fact; the index line is kept in sync.
 * The files live on each machine, outside any repo (Configs is public). PI_MEMORY=0 turns it off.
 */
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { StringEnum, Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ON = process.env.PI_MEMORY !== "0";
const ROOT = process.env.PI_MEMORY_DIR || join(homedir(), ".pi", "memory");
const MAX_INDEX = 3000; // chars per index in the prompt

const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 60);

/** A folder name for a project path: readable tail plus a hash, so long paths don't collide. */
function projectKey(dir: string): string {
	const rel = dir.startsWith(homedir()) ? dir.slice(homedir().length) : dir;
	const s = rel.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
	return s.length <= 60 ? s : `${s.slice(-50)}-${createHash("sha256").update(dir).digest("hex").slice(0, 8)}`;
}

/** The project folder for a cwd: the deepest one that already has memories, else the cwd. */
function projectDir(cwd: string): string {
	const base = join(ROOT, "projects");
	let dir = cwd;
	while (dir !== "/" && dir !== homedir()) {
		const d = join(base, projectKey(dir));
		if (existsSync(d)) return d;
		dir = join(dir, "..");
	}
	return join(base, projectKey(cwd));
}

function index(dir: string): string {
	const p = join(dir, "MEMORY.md");
	if (!existsSync(p)) return "";
	const text = readFileSync(p, "utf8").trim();
	return text.length > MAX_INDEX ? `${text.slice(0, MAX_INDEX)}\n[... index cut; ls ${dir} for the rest]` : text;
}

/** Rewrite MEMORY.md from the files' frontmatter, so it never drifts. */
function reindex(dir: string) {
	const lines = readdirSync(dir)
		.filter((f) => f.endsWith(".md") && f !== "MEMORY.md")
		.sort()
		.map((f) => {
			const head = readFileSync(join(dir, f), "utf8").slice(0, 600);
			const desc = head.match(/^description:\s*(.+)$/m)?.[1] ?? "";
			return `- [${f.replace(/\.md$/, "")}](${join(dir, f)}) — ${desc}`;
		});
	if (lines.length) writeFileSync(join(dir, "MEMORY.md"), `${lines.join("\n")}\n`);
	else rmSync(join(dir, "MEMORY.md"), { force: true });
}

const memoryTool = defineTool({
	name: "memory",
	label: "Memory",
	description:
		"Save a fact for future sessions, or forget one. Save when the user asks you to remember something, or when you " +
		"learn something durable: who they are and how they like to work (scope global), or a project decision, " +
		"constraint or pointer that the code and git history don't show (scope project). One fact per memory; saving " +
		"an existing name replaces it, so update rather than duplicate. Don't save secrets, or what's only true today.",
	promptSnippet: "memory: save or forget a fact for future sessions",
	parameters: Type.Object({
		action: StringEnum(["save", "forget"] as const),
		name: Type.String({ description: "Short kebab-case name, e.g. prefers-small-commits" }),
		scope: StringEnum(["global", "project"] as const, { description: "global: every project; project: this one" }),
		description: Type.Optional(Type.String({ description: "One line, used to decide relevance later (save)" })),
		type: Type.Optional(StringEnum(["user", "feedback", "project", "reference"] as const)),
		body: Type.Optional(Type.String({ description: "The fact. For feedback/project add **Why:** and **How to apply:** lines" })),
	}),
	async execute(_id, params, _signal, _update, ctx) {
		const dir = params.scope === "global" ? ROOT : projectDir(ctx.cwd);
		const file = join(dir, `${slug(params.name)}.md`);
		if (params.action === "forget") {
			if (!existsSync(file)) return { content: [{ type: "text", text: `No memory named ${params.name} in ${dir}.` }], details: undefined };
			rmSync(file);
			reindex(dir);
			return { content: [{ type: "text", text: `Forgot ${params.name}.` }], details: undefined };
		}
		if (!params.description || !params.body)
			return { content: [{ type: "text", text: "save needs description and body." }], details: undefined };
		mkdirSync(dir, { recursive: true });
		const replaced = existsSync(file);
		writeFileSync(
			file,
			`---\nname: ${slug(params.name)}\ndescription: ${params.description.replace(/\n/g, " ")}\n` +
				`type: ${params.type ?? "project"}\nsaved: ${new Date().toISOString().slice(0, 10)}\n---\n\n${params.body.trim()}\n`,
		);
		reindex(dir);
		return { content: [{ type: "text", text: `${replaced ? "Updated" : "Saved"} ${file}` }], details: undefined };
	},
});

export default function (pi: ExtensionAPI) {
	if (!ON) return;
	pi.registerTool(memoryTool);
	pi.on("before_agent_start", (event, ctx) => {
		const global = index(ROOT);
		const project = index(projectDir(ctx.cwd));
		const parts = [
			"# Memory",
			"Facts saved in earlier sessions. Each line is a file: read it when it looks relevant to the task. Memories " +
				"reflect when they were saved; check a named file or flag still exists before relying on it. When the user " +
				"says to remember something, save it with the `memory` tool (update an existing one instead of duplicating); " +
				"when they say to forget something, forget it.",
			global ? `## About the user and how they work\n${global}` : "",
			project ? `## This project\n${project}` : "",
		].filter(Boolean);
		return { systemPrompt: `${event.systemPrompt}\n\n${parts.join("\n\n")}` };
	});
}
