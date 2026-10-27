/**
 * For `reader` workers run by pi-orch: the claims file is the deliverable, so the run can't
 * end without it (like a SubagentStop hook in Claude Code).
 *
 * Only active when PI_CLAIMS_FILE is set (pi-orch sets it per slice).
 * - agent_before_settle: if the file is missing or isn't the expected JSON, the run continues
 *   with a message saying what's wrong; at most 2 times, then it ends and pi-orch retries or
 *   marks the slice failed.
 * - tool_call: write and edit go only to the claims file (readers never change the project).
 */
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const FILE = process.env.PI_CLAIMS_FILE;
const NUDGES = 2;

/** What's wrong with the claims file, or "" when it's usable. */
function problem(): string {
	if (!FILE || !existsSync(FILE)) return `You haven't written your claims file (${FILE}).`;
	let data: unknown;
	try {
		data = JSON.parse(readFileSync(FILE, "utf8"));
	} catch (e) {
		return `Your claims file isn't valid JSON (${(e as Error).message}).`;
	}
	const d = data as { claims?: unknown; garbled?: unknown };
	if (!Array.isArray(d.claims)) return "Your claims file has no `claims` array.";
	if (d.garbled === true) return "";
	const bad = d.claims.filter(
		(c) => !c || typeof c !== "object" || !(c as { quote?: unknown }).quote || !(c as { line?: unknown }).line,
	);
	if (bad.length) return `${bad.length} of your claims have no \`quote\` or \`line\`.`;
	if (!d.claims.length) return "Your claims file has no claims. Add what you found, each with file, line and quote.";
	return "";
}

export default function (pi: ExtensionAPI) {
	if (!FILE) return;
	let nudged = 0;

	pi.on("tool_call", (event, ctx) => {
		if (event.toolName !== "write" && event.toolName !== "edit") return;
		const target = resolve(ctx.cwd, String((event.input as { path?: string }).path ?? ""));
		if (target !== resolve(FILE))
			return { block: true, reason: `Readers only write their claims file: ${FILE}` };
	});

	pi.on("agent_before_settle", (event) => {
		if (event.outcome === "aborted" || nudged >= NUDGES) return;
		const why = problem();
		if (!why) return;
		nudged++;
		return {
			continue: true,
			entries: [
				{
					type: "custom_message",
					customType: "claims",
					display: true,
					content:
						`${why} Write it now to ${FILE} (the JSON shape in your instructions), ` +
						"from what you've already found. Don't read anything else first.",
				},
			],
		};
	});
}
