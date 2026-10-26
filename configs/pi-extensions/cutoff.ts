/**
 * Output cut off at the token limit (stopReason "length"): keep the agent going with a nudge
 * instead of ending the run.
 *
 * Found in the Flint bake-off (ai-stack docs/BAKEOFF.md): it wrote whole Rust libraries in one
 * `write` and hit the 16k output cap. Pi itself refuses to run the truncated tool call, but
 * when the cut-off message is the last one, `pi -p` ends the run, so the agent never fixed the
 * broken file it had left. All four Rust runs failed to compile this way.
 *
 * turn_end: if the message was cut off, add a short instruction and continue, at most
 * MAX_RESUMES times in a row. The system prompt (pi-agents/APPEND_SYSTEM.md) asks for files
 * in parts so it rarely comes to this.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MAX_RESUMES = 3;
const NUDGE =
	"Your last message was cut off at the output limit, so its file changes were not applied. " +
	"Write big files in parts: a short skeleton first, then add at most ~150 lines per edit. " +
	"Check the file's current state before continuing.";

export default function (pi: ExtensionAPI) {
	let resumes = 0;

	pi.on("turn_end", (event) => {
		const m = event.message as { stopReason?: string };
		if (m.stopReason !== "length") {
			resumes = 0;
			return;
		}
		if (resumes >= MAX_RESUMES) return;
		resumes++;
		return {
			entries: [{ type: "custom_message", customType: "cutoff", content: NUDGE, display: true }],
			continue: true,
		};
	});
}
