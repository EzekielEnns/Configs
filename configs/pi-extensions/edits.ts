/**
 * Change existing files with `edit`, not by writing them out again (ai-stack docs/CODING-PLAN.md
 * step 1).
 *
 * In the Flint bake-off it rewrote whole Rust files in 5-7k-token `write` calls, again and
 * again, until it ran out of time. SWE-agent's ablation: without an edit command, 18.0% →
 * 10.3% solved.
 *
 * - tool_call: `write` to an existing file over PI_WRITE_MAX_LINES (default 150) is refused
 *   with a pointer to `edit`. New files and short ones can still be written whole.
 * - tool_result: when `edit` can't find its old text, the result also shows the lines of the
 *   file that look most like it, so a near miss (whitespace, a changed line) costs one retry,
 *   not a rewrite.
 */
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MAX_LINES = Number(process.env.PI_WRITE_MAX_LINES) || 150;

const words = (s: string) => new Set(s.toLowerCase().match(/\w+/g) ?? []);

/** The window of the file most like `old`, by shared words, with line numbers. */
function nearest(file: string, old: string): string | undefined {
	const lines = file.split("\n");
	const n = Math.max(1, Math.min(old.split("\n").length, 30));
	const target = words(old);
	if (!target.size) return undefined;
	let best = -1;
	let at = 0;
	for (let i = 0; i + n <= lines.length; i++) {
		const w = words(lines.slice(i, i + n).join("\n"));
		let shared = 0;
		for (const t of target) if (w.has(t)) shared++;
		const score = shared / target.size;
		if (score > best) [best, at] = [score, i];
	}
	if (best < 0.3) return undefined;
	const from = Math.max(0, at - 2);
	const to = Math.min(lines.length, at + n + 2);
	return lines
		.slice(from, to)
		.map((l, i) => `${String(from + i + 1).padStart(5)}  ${l}`)
		.join("\n");
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", (event, ctx) => {
		if (event.toolName !== "write") return;
		const path = resolve(ctx.cwd, String(event.input.path ?? ""));
		if (!existsSync(path)) return;
		const lines = readFileSync(path, "utf8").split("\n").length;
		if (lines <= MAX_LINES) return;
		return {
			block: true,
			reason:
				`${event.input.path} already has ${lines} lines: don't write it out again. Change it with edit ` +
				"(small, unique oldText per change; several edits in one call is fine). Read or grep the lines first if unsure.",
		};
	});

	pi.on("tool_result", (event, ctx) => {
		if (event.toolName !== "edit" || !event.isError) return;
		const text = event.content.map((c) => (c.type === "text" ? c.text : "")).join("\n");
		const missing = text.match(/Could not find (?:edits\[(\d+)\]|the exact text)/);
		if (!missing) return;
		const edits = (event.input.edits ?? []) as { oldText?: string }[];
		const old = edits[Number(missing[1] ?? 0)]?.oldText;
		const path = resolve(ctx.cwd, String(event.input.path ?? ""));
		if (!old || !existsSync(path)) return;
		const near = nearest(readFileSync(path, "utf8"), old);
		if (!near) return;
		return {
			content: [
				...event.content,
				{ type: "text", text: `\nClosest lines in the file now (copy oldText from here exactly, without the line numbers):\n${near}` },
			],
		};
	});
}
