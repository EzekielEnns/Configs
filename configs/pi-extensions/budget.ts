/**
 * Work budget for sub-agents on small context windows. Only active when PI_TOOL_BUDGET is
 * set (the subagent extension sets it from an agent's `max_tool_calls`).
 *
 * - Results say how many tool calls are left once few remain, and when context fills up.
 * - Past the budget, or once context is PI_WRAP_AT full (default 0.6), tool calls are
 *   refused with "write your answer now"; `note` and `write` stay allowed so findings get
 *   saved (researchers use note; workers write the notes file their brief names).
 * - If the agent keeps calling refused tools (4 refusals) or context reaches PI_STOP_AT (0.85),
 *   the run is ended; the parent still has whatever was saved with `note`.
 * - Small models drift from their instructions, so results also nudge: reads are capped at
 *   80 lines, a repeated read is refused, grep defaults to the run's saved pages, and an
 *   agent that hasn't saved a note after a few calls is reminded to, and the same bash command
 *   with only numbers changed (paging through a file with sed) is refused after 4 of the last 6
 *   calls: an orchestrated worker did that 91 times until its context ran out.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const BUDGET = Number(process.env.PI_TOOL_BUDGET) || 0;
const WRAP_AT = Number(process.env.PI_WRAP_AT) || 0.6;
const STOP_AT = Number(process.env.PI_STOP_AT) || 0.85;
const ALWAYS_ALLOWED = new Set(["note", "write"]);
const shape = (cmd: string) => cmd.replace(/\d+/g, "#").replace(/\s+/g, " ").trim();

export default function (pi: ExtensionAPI) {
	if (!BUDGET) return;
	let calls = 0;
	let refused = 0;
	let notes = 0;
	const reads = new Set<string>();
	const recent: string[] = [];

	const fullness = (ctx: { getContextUsage(): { percent: number | null } | undefined }) =>
		(ctx.getContextUsage()?.percent ?? 0) / 100;

	pi.on("tool_call", (event, ctx) => {
		if (event.toolName === "note" || event.toolName === "write") notes++;
		if (ALWAYS_ALLOWED.has(event.toolName)) return;
		// grep without a path would search the working directory; the saved pages are what
		// a researcher means.
		if (event.toolName === "grep" && !(event.input as { path?: string }).path && process.env.PI_RESEARCH_DIR) {
			(event.input as { path?: string }).path = `${process.env.PI_RESEARCH_DIR}/pages`;
		}
		if (event.toolName === "read") {
			const input = event.input as { path?: string; offset?: number; limit?: number };
			if (input.limit === undefined || input.limit > 80) input.limit = 80;
			const key = `${input.path}:${input.offset ?? 1}`;
			if (reads.has(key)) {
				refused++;
				return { block: true, reason: "You already read this part; it's above. Use grep on the file to find something specific." };
			}
			reads.add(key);
		}
		if (event.toolName === "bash") {
			const s = shape(String((event.input as { command?: string }).command ?? ""));
			recent.push(s);
			if (recent.length > 6) recent.shift();
			if (recent.filter((r) => r === s).length >= 4) {
				refused++;
				return {
					block: true,
					reason:
						"You've run this same command with different numbers 4 times. Stop paging: grep for the specific " +
						"things your task asks about, or save what you have and finish.",
				};
			}
		}
		const full = fullness(ctx);
		// Every refused call counts, so an agent retrying refused calls is stopped.
		if (full >= STOP_AT || refused >= 4) {
			return { block: true, terminate: true, reason: "Stopped: out of budget. Your saved notes will be used." };
		}
		if (calls >= BUDGET || full >= WRAP_AT) {
			refused++;
			const why = calls >= BUDGET ? `all ${BUDGET} tool calls used` : `context is ${Math.round(full * 100)}% full`;
			return {
				block: true,
				reason: `Budget reached (${why}). Do not call more tools. Save anything unsaved (note, or write the notes file your task names), then write your final answer now from what you have.`,
			};
		}
		calls++;
	});

	pi.on("tool_result", (event, ctx) => {
		if (event.isError) return;
		const left = BUDGET - calls;
		const full = fullness(ctx);
		const hints: string[] = [];
		if (left <= 3) hints.push(`${left} tool call${left === 1 ? "" : "s"} left`);
		if (full >= WRAP_AT - 0.15) hints.push(`context ${Math.round(full * 100)}% full, wrap up soon`);
		if (notes === 0 && calls >= 5) hints.push("nothing saved yet: save what you've confirmed (note, or write the notes file your task names)");
		if (!hints.length) return;
		return {
			content: [...event.content, { type: "text", text: `[budget: ${hints.join("; ")}]` }],
			structuredContent: event.structuredContent,
		};
	});
}
