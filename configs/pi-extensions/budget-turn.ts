/**
 * Reasoning budget per turn (ai-stack docs/CODING-PLAN.md step 3).
 *
 * Flint reasons up to its 2k budget before every tool call, even after a clean `ls`: in the
 * bake-off reasoning was 41-86% of its output, 90% on one Go task. So:
 * - full budget (PI_BUDGET_HIGH, default 2048) when it has to think: answering a new user
 *   message, or after a failed command, check or edit;
 * - small budget (PI_BUDGET_LOW, default 384) for routine turns after tool results that went fine.
 *
 * before_provider_request: sets llama.cpp's per-request `reasoning_budget_tokens` (checked on
 * our build: 64 cut a 4.9k-char answer's reasoning to 350 chars, same answer). Requests must
 * reach llama-server with the field intact (llama-swap directly, or a gateway that passes
 * unknown fields through; LiteLLM does). Only for the models in PI_BUDGET_MODELS (default
 * `flint`: not flint-careful, which is meant to think freely, nor hosted models).
 * PI_BUDGET_TURN=0 turns it off.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ON = process.env.PI_BUDGET_TURN !== "0";
const HIGH = Number(process.env.PI_BUDGET_HIGH) || 2048;
const LOW = Number(process.env.PI_BUDGET_LOW) || 384;
const MODELS = new Set((process.env.PI_BUDGET_MODELS ?? "flint").split(","));

const FAILED =
	/\[(?:cargo check|go vet|ruff[^\]]*|py_compile): \d+ error|error\[E\d+\]|^error:|\bFAILED\b|\b[1-9]\d* failed\b|--- FAIL|panicked|Traceback|Could not find|exited with code [1-9]|exit code [1-9]|command not found|No such file/m;

type Msg = { role: string; content?: unknown };

const text = (c: unknown) =>
	typeof c === "string" ? c : Array.isArray(c) ? c.map((p) => (p as { text?: string }).text ?? "").join("\n") : "";

export default function (pi: ExtensionAPI) {
	if (!ON) return;
	pi.on("before_provider_request", (event) => {
		const payload = event.payload as { model?: string; messages?: Msg[]; reasoning_budget_tokens?: number } | undefined;
		if (!payload?.messages?.length || !MODELS.has(String(payload.model))) return;
		const msgs = payload.messages;
		// The results since the model last spoke.
		const recent: Msg[] = [];
		for (let i = msgs.length - 1; i >= 0 && msgs[i].role !== "assistant"; i--) recent.push(msgs[i]);
		const fresh = recent.some((m) => m.role === "user") || recent.length === 0;
		const failed = recent.some((m) => m.role === "tool" && FAILED.test(text(m.content)));
		payload.reasoning_budget_tokens = fresh || failed ? HIGH : LOW;
		return payload;
	});
}
