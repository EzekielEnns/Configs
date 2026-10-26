/**
 * Send only the latest thinking back to the model.
 *
 * Pi replays every assistant message's thinking on each request, and on our 32k slots that
 * was 40-60% of the context in the Flint bake-off (ai-stack docs/BAKEOFF.md). Flint's 2k
 * thinking budget made it worse: on hitting the budget it ran `echo ok` just to keep
 * thinking next turn, 5-7 times per Rust task, until the context was full.
 *
 * context: drop the thinking blocks of all but the last KEEP assistant messages. The session
 * keeps them (Ctrl+T still shows them); only the request gets shorter.
 *
 * Only once the context is PI_TRIM_THINKING_AT percent full (default 50; 0 = always), and from
 * then on for the rest of the session, so the prompt doesn't flip back and forth. Flint's chat
 * template sends old reasoning back, and trimming from the start cost points on short Go and
 * Python tasks that never ran short of room.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const KEEP = Number(process.env.PI_KEEP_THINKING) || 2;
const AT = Number(process.env.PI_TRIM_THINKING_AT ?? 50);

type Block = { type: string };
type Msg = { role: string; content?: Block[] | string };

export default function (pi: ExtensionAPI) {
	let on = AT <= 0;

	pi.on("context", (event, ctx) => {
		const messages = event.messages as Msg[];
		if (!on) {
			const usage = ctx.getContextUsage();
			// Right after compaction Pi doesn't know yet: estimate at ~3.5 chars per token.
			const percent =
				usage?.percent ?? (usage ? (100 * JSON.stringify(messages).length) / 3.5 / usage.contextWindow : 0);
			if (percent < AT) return;
			on = true;
		}
		let seen = 0;
		let changed = false;
		const out = [...messages];
		for (let i = out.length - 1; i >= 0; i--) {
			const m = out[i];
			if (m.role !== "assistant" || !Array.isArray(m.content)) continue;
			if (++seen <= KEEP) continue;
			const content = m.content.filter((c) => c.type !== "thinking");
			if (content.length === m.content.length) continue;
			out[i] = { ...m, content: content.length ? content : [{ type: "text", text: "" } as Block] };
			changed = true;
		}
		if (changed) return { messages: out as typeof event.messages };
	});
}
