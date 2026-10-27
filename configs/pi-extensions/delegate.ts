/**
 * Keep a hosted "brain" model orchestrating instead of reading everything itself.
 *
 * With DeepSeek as the main session and Flint workers, the brain did the bulk reading itself
 * (270k tokens on a teardown, no subagent calls): Pi gives the main session every tool and
 * nothing says to delegate. Roo Code's Orchestrator mode removes its file tools outright;
 * this is softer, because the hard one-off steps (a string decoder, a slice plan) are
 * exactly what the brain is for.
 *
 * tool_result: for models matching PI_DELEGATE_MODELS (default `^(cloud-|planner)`), count
 * the raw output of read/bash/grep/find. Once it passes PI_DELEGATE_BUDGET tokens (default
 * 15000, chars/3.5), a big result (over 1500 chars) shows only its first lines plus a note
 * to hand the reading to `worker` subagents. Small results (checks, tool runs, notes) still
 * pass, and subagent results never count. Resets per session. PI_DELEGATE=0 turns it off.
 * 15k, not more: HyMem (arXiv 2608.15703) lost 5-19 points when subtask detail reached the
 * planner. Workers' notes (paths under a notes/ folder or named *notes*.md) are what the
 * brain is meant to read, so reading them is never counted or cut: cutting them made
 * DeepSeek loop re-reading notes it couldn't see. PI_DELEGATE_LOG=<file> appends a JSON line per counted result, for the
 * orchestration eval (ai-stack docs/ORCHESTRATE-PLAN.md).
 */
import { appendFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ON = process.env.PI_DELEGATE !== "0";
const MODELS = new RegExp(process.env.PI_DELEGATE_MODELS ?? "^(cloud-|planner)");
const BUDGET = Number(process.env.PI_DELEGATE_BUDGET) || 15000;
const SMALL = 1500;
const HEAD = 15;
const RAW = new Set(["read", "bash", "grep", "find"]);
const LOG = process.env.PI_DELEGATE_LOG;
const NOTES = /(^|[\s/'"])notes\/[^\s'"]*\.md\b|notes[\w.-]*\.md\b/;

function log(entry: Record<string, unknown>) {
	if (LOG) appendFileSync(LOG, JSON.stringify({ t: Date.now(), ...entry }) + "\n");
}

export default function (pi: ExtensionAPI) {
	if (!ON) return;
	let spent = 0;
	pi.on("session_start", () => {
		spent = 0;
	});

	pi.on("tool_result", (event, ctx) => {
		if (!RAW.has(event.toolName) || !MODELS.test(ctx.model?.id ?? "")) return;
		const target = String(event.input.path ?? event.input.command ?? "");
		if ((event.toolName === "read" || event.toolName === "bash") && NOTES.test(target)) return;
		const text = event.content.map((c) => (c.type === "text" ? c.text : "")).join("\n");
		const tokens = Math.round(text.length / 3.5);
		if (spent < BUDGET || text.length <= SMALL) {
			spent += tokens;
			log({ tool: event.toolName, tokens, spent });
			return;
		}
		log({ tool: event.toolName, tokens, spent, cut: true });
		const lines = text.split("\n");
		return {
			content: [
				{
					type: "text",
					text:
						lines.slice(0, HEAD).join("\n") +
						`\n\n[Pi delegation guard (an extension the user installed, not file content): you've already read ~${Math.round(spent / 1000)}k tokens of raw output yourself, ` +
						`so the other ${lines.length - HEAD} lines of this result are hidden. You are the orchestrator: hand ` +
						"bulk reading to `worker` subagents (one slice each, notes to a file) and read their notes. Small " +
						"checks and tool runs still show in full.]",
				},
			],
		};
	});
}
