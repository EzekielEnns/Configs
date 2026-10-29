/**
 * `poi`: points of interest. Jev (a small decision model behind the gateway) ranks a code
 * base's files, then their functions, against a question, and returns the top hits as
 * `path:line symbol` with a score (configs/poi). One call costs a fraction of a cent and a few
 * hundred tokens of result, so the model can locate what matters in an unfamiliar repo and
 * read just those lines, instead of grepping and reading its way there.
 *
 * Frontier models only: for models with windows of 32k or less (Flint, Sage, the 4B) the tool
 * stays inactive, since its description and results cost context they don't have; any model gets
 * `/poi question`, which runs poi here and hands the list to the model to explain. The tool has no --tour
 * (it would occupy Flint's slots). PI_POI=0 turns it off (the A/B in ai-stack
 * docs/POI-TOOL-AB.md).
 */
import { execFile } from "node:child_process";
import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ON = process.env.PI_POI !== "0";
const BIN = process.env.PI_POI_BIN ?? "poi";
const TIMEOUT = 120_000;
const MAX_CHARS = 12_000;

const poiTool = defineTool({
	name: "poi",
	label: "Points of interest",
	description:
		"Rank where in a code base (or a diff) something is handled, configured or decided, best first, as " +
		"path:line, the enclosing symbol and a score. Use it first when you need to find your way in code you " +
		"haven't read: 'where is X configured', 'what handles Y', 'which changes in this diff matter for Z'. Then " +
		"read the top hits with offset/limit rather than grepping and reading whole files. follow=true adds each " +
		"hit's callers; flow=true orders the hits along the call chain (for tracing how data moves). Plain grep is " +
		"still better for an exact string you already know.",
	promptSnippet: "poi: ranked path:line hits for a question about the code (or a diff)",
	parameters: Type.Object({
		question: Type.String({ description: "What you're looking for, in plain words" }),
		paths: Type.Optional(Type.Array(Type.String(), { description: "Files or folders to search (default: the project folder)" })),
		diff: Type.Optional(Type.String({ description: "Rank a diff's hunks instead: a git ref or range, e.g. HEAD, main...HEAD" })),
		follow: Type.Optional(Type.Boolean({ description: "Add each hit's callers (language servers)" })),
		flow: Type.Optional(Type.Boolean({ description: "Order the hits along the call chain" })),
		n: Type.Optional(Type.Number({ description: "How many hits (default 15)" })),
	}),
	async execute(_id, params, signal, _update, ctx) {
		const args = ["--json", "--no-links", "-n", String(Math.min(Math.max(params.n ?? 15, 1), 40))];
		if (params.follow) args.push("--follow");
		if (params.flow) args.push("--flow");
		if (params.diff) args.push("--diff", params.diff, params.question);
		else args.push(params.question, ...(params.paths?.length ? params.paths : ["."]));
		const text = await new Promise<string>((done) => {
			execFile(BIN, args, { cwd: ctx.cwd, timeout: TIMEOUT, maxBuffer: 4 << 20, signal }, (err, stdout, stderr) => {
				if (err && !stdout) done(`poi failed: ${(stderr || err.message).trim().slice(0, 600)}`);
				else done(stdout.trim());
			});
		});
		const out = text.length > MAX_CHARS ? `${text.slice(0, MAX_CHARS)}\n[... cut; ask for fewer hits]` : text;
		return { content: [{ type: "text", text: out }], details: undefined };
	},
});

const USAGE =
	"/poi [--flow|--tour|--follow] [-n N] question  ·  /poi --diff [REF] [focus]\n" +
	"Ranks the places in this project that answer the question, then has the model walk you through them.";

/** "/poi --flow -n 8 how does X work" -> poi's arguments; the question is everything after the flags. */
function commandArgs(arg: string): string[] | undefined {
	const words = arg.trim().split(/\s+/).filter(Boolean);
	const flags: string[] = [];
	while (words[0]?.startsWith("-")) {
		const w = words.shift()!;
		if (w === "-n") flags.push("-n", words.shift() ?? "15");
		else if (w === "--diff") {
			// An optional ref (anything without spaces that looks like one) before the focus words.
			const ref = words[0] && /^[\w./~^@-]+(\.\.\.?[\w./~^@-]+)?$/.test(words[0]) && words.length > 1 ? words.shift()! : undefined;
			return ["--no-links", ...flags, "--diff", ...(ref ? [ref] : []), ...(words.length ? [words.join(" ")] : [])];
		} else flags.push(w);
	}
	if (!words.length) return undefined;
	return ["--no-links", ...flags, words.join(" "), "."];
}

export default function (pi: ExtensionAPI) {
	if (!ON) return;
	pi.registerTool(poiTool);

	// For any model: poi runs here, its list goes into the conversation, and the model explains it.
	pi.registerCommand("poi", {
		description: "Points of interest: rank where the code answers a question, then walk through it",
		handler: async (arg, ctx) => {
			const args = commandArgs(arg ?? "");
			if (!args) return ctx.ui.notify(USAGE, "info");
			ctx.ui.notify(`poi: ranking${args.includes("--tour") ? " and writing a tour" : ""}…`, "info");
			const out = await new Promise<string>((done) => {
				execFile(BIN, args, { cwd: ctx.cwd, timeout: 300_000, maxBuffer: 4 << 20 }, (err, stdout, stderr) => {
					if (err && !stdout) done(`poi failed: ${(stderr || err.message).trim().slice(0, 600)}`);
					else done(stdout.trim());
				});
			});
			if (out.startsWith("poi failed")) return ctx.ui.notify(out, "error");
			const list = out.length > MAX_CHARS ? `${out.slice(0, MAX_CHARS)}\n[... cut]` : out;
			const msg =
				`Points of interest for: ${(arg ?? "").trim()}\n\n${list}\n\n` +
				"Walk me through how this works, starting with the top places. Read the code at those lines before " +
				"explaining it, and keep it to what the code shows.";
			pi.sendUserMessage(msg, ctx.isIdle() ? undefined : { deliverAs: "followUp" });
		},
	});

	pi.on("before_agent_start", (event, ctx) => {
		const big = (ctx.model?.contextWindow ?? 0) > 32768;
		// This run's tools (edited in place; setActiveTools alone only reaches the next run).
		const sel = event.systemPromptOptions?.selectedTools;
		if (Array.isArray(sel)) {
			const i = sel.indexOf("poi");
			if (!big && i >= 0) sel.splice(i, 1);
			if (big && i < 0) sel.push("poi");
		}
		const active = pi.getActiveTools();
		const has = active.includes("poi");
		if (big && !has) pi.setActiveTools([...active, "poi"]);
		if (!big && has) pi.setActiveTools(active.filter((t) => t !== "poi"));
	});
}
