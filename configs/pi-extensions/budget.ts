/**
 * Work budget for sub-agents on small context windows. Only active when PI_TOOL_BUDGET is
 * set (the subagent extension sets it from an agent's `max_tool_calls`).
 *
 * - Results say how many tool calls are left once few remain, and when context fills up.
 * - Past the budget, or once context is PI_WRAP_AT full (default 0.6), tool calls are
 *   refused with "write your answer now"; `note` stays allowed so findings get saved.
 * - If the agent keeps calling refused tools (4 refusals) or context reaches PI_STOP_AT (0.85),
 *   the run is ended; the parent still has whatever was saved with `note`.
 * - Small models drift from their instructions, so results also nudge: reads are capped at
 *   80 lines, a repeated read is refused, grep defaults to the run's saved pages, and an
 *   agent that hasn't saved a note after a few calls is reminded to.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const BUDGET = Number(process.env.PI_TOOL_BUDGET) || 0;
const WRAP_AT = Number(process.env.PI_WRAP_AT) || 0.6;
const STOP_AT = Number(process.env.PI_STOP_AT) || 0.85;
const ALWAYS_ALLOWED = new Set(["note"]);

export default function (pi: ExtensionAPI) {
	if (!BUDGET) return;
	let calls = 0;
	let refused = 0;
	let notes = 0;
	const reads = new Set<string>();

	const fullness = (ctx: { getContextUsage(): { percent: number | null } | undefined }) =>
		(ctx.getContextUsage()?.percent ?? 0) / 100;

	pi.on("tool_call", (event, ctx) => {
		if (event.toolName === "note") notes++;
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
				reason: `Budget reached (${why}). Do not call more tools. Save anything unsaved with note, then write your final answer now from what you have.`,
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
		if (notes === 0 && calls >= 5) hints.push("no notes saved yet: call note for each fact you've confirmed");
		if (!hints.length) return;
		return {
			content: [...event.content, { type: "text", text: `[budget: ${hints.join("; ")}]` }],
			structuredContent: event.structuredContent,
		};
	});
}
