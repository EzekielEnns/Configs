/**
 * Log llama.cpp's per-request timings, for the bake-off (ai-stack docs/CODING-PLAN.md step 0).
 *
 * llama-server ends each streamed response with `timings`: prompt tokens processed and how
 * long that took, tokens reused from its cache, tokens generated. That shows what history
 * rewriting (thinking.ts, mask.ts) costs in prompt processing. LiteLLM drops the field, so
 * the provider has to point at llama-swap itself.
 *
 * Only with PI_TIMINGS_FILE set: one JSON line per request is appended there.
 */
import { appendFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const FILE = process.env.PI_TIMINGS_FILE;

export default function (pi: ExtensionAPI) {
	if (!FILE) return;
	let turn = 0;
	pi.on("provider_stream_event", (event) => {
		const t = (event.data as { timings?: Record<string, number> } | undefined)?.timings;
		if (!t) return;
		turn++;
		const line = {
			turn,
			time: new Date().toISOString(),
			model: event.model,
			cache_n: t.cache_n,
			prompt_n: t.prompt_n,
			prompt_ms: Math.round(t.prompt_ms),
			predicted_n: t.predicted_n,
			predicted_ms: Math.round(t.predicted_ms),
		};
		appendFileSync(FILE, `${JSON.stringify(line)}\n`);
	});
}
