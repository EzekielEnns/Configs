/**
 * Hide old tool output and old file contents from the model (observation masking).
 *
 * In the Flint bake-off (ai-stack docs/BAKEOFF.md) old `read`/`bash` output and the full
 * contents of earlier `write` calls were 20-60% of the context, long after the agent had
 * moved on. Masking old observations with a placeholder matched LLM summarization on
 * SWE-bench at half the cost ("The Complexity Trap", arXiv 2508.21433).
 *
 * context: tool results older than the last KEEP are replaced by a one-line note (the
 * session keeps them; only the request gets shorter); `write`/`edit` calls older than the
 * last KEEP assistant messages keep their path but not their text, since the file is on disk.
 * The boundary moves STEP results at a time so the prompt prefix, and llama.cpp's cache of
 * it, stays the same between most turns. PI_MASK=0 turns it off.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ON = process.env.PI_MASK !== "0";
const KEEP = Number(process.env.PI_MASK_KEEP) || 4;
const STEP = 4;
const MIN_CHARS = 400;

type Block = { type: string; text?: string; id?: string; name?: string; arguments?: Record<string, unknown> };
type Msg = { role: string; content?: Block[] | string; toolCallId?: string; toolName?: string };

const lines = (s: string) => s.split("\n").length;

function maskCall(c: Block): Block {
	const a = c.arguments ?? {};
	if (c.name === "write" && typeof a.content === "string" && a.content.length > MIN_CHARS)
		return { ...c, arguments: { ...a, content: `[${lines(a.content)} lines written; read ${a.path} for its current contents]` } };
	if (c.name === "edit" && Array.isArray(a.edits) && JSON.stringify(a.edits).length > MIN_CHARS)
		return { ...c, arguments: { ...a, edits: [{ oldText: "[earlier edit, hidden]", newText: `[${a.edits.length} change(s) applied to ${a.path}]` }] } };
	return c;
}

export default function (pi: ExtensionAPI) {
	if (!ON) return;
	pi.on("context", (event) => {
		const out = [...(event.messages as Msg[])];
		const calls = new Map<string, Block>();
		const results: number[] = [];
		const assistants: number[] = [];
		out.forEach((m, i) => {
			if (m.role === "toolResult") results.push(i);
			if (m.role === "assistant" && Array.isArray(m.content)) {
				assistants.push(i);
				for (const c of m.content) if (c.type === "toolCall" && c.id) calls.set(c.id, c);
			}
		});
		let changed = false;

		const boundary = (n: number) => Math.floor(Math.max(0, n - KEEP) / STEP) * STEP;
		for (const i of results.slice(0, boundary(results.length))) {
			const m = out[i];
			if (!Array.isArray(m.content)) continue;
			const text = m.content.map((c) => c.text ?? "").join("\n");
			if (text.length < MIN_CHARS) continue;
			const call = calls.get(m.toolCallId ?? "");
			const args = call?.arguments ?? {};
			const what =
				m.toolName === "read"
					? `read of ${args.path}`
					: m.toolName === "bash"
						? `output of \`${String(args.command ?? "").slice(0, 80)}\``
						: `${m.toolName} result`;
			out[i] = { ...m, content: [{ type: "text", text: `[Earlier ${what} hidden: ${lines(text)} lines. Run it again if you still need it.]` }] };
			changed = true;
		}

		for (const i of assistants.slice(0, boundary(assistants.length))) {
			const m = out[i];
			const content = (m.content as Block[]).map((c) => (c.type === "toolCall" ? maskCall(c) : c));
			if (content.some((c, j) => c !== (m.content as Block[])[j])) {
				out[i] = { ...m, content };
				changed = true;
			}
		}
		if (changed) return { messages: out as typeof event.messages };
	});
}
