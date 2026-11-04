/**
 * Real cost, from OpenRouter, instead of a price list.
 *
 * - Each reply: the gateway passes OpenRouter's `usage.cost` (dollars actually charged, on the
 *   host that served it) through in the last stream chunk. It goes into the reply's usage, so
 *   Pi's footer and `/session` show what was billed. Local models have no cost and stay $0.
 * - Status line: the OpenRouter key's spend today, this week and this month, and what's left of
 *   its limit. That's everything on the key: every machine, pis, sub-agents, Jev (poi, guards).
 *   It comes from the gateway's GET /openrouter/key (ai-stack), which adds the key, and is
 *   refreshed when a session starts and after each run.
 * - `/usage`: this session's cost by model, then the key's totals.
 *
 * PI_COST=0 turns it off; PI_COST_URL points at another gateway.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ON = process.env.PI_COST !== "0";
const URL = process.env.PI_COST_URL ?? "http://desktop:4000/openrouter/key";
const REFRESH_MS = 30_000;

type KeyInfo = {
	usage?: number;
	usage_daily?: number;
	usage_weekly?: number;
	usage_monthly?: number;
	limit?: number | null;
	limit_remaining?: number | null;
	limit_reset?: string | null;
};
type Usage = { input: number; output: number; cacheRead: number; cacheWrite: number; cost: Record<string, number> };
type Msg = { role: string; model?: string; responseId?: string; usage?: Usage };

const usd = (n: number) => (n < 1 ? `$${n.toFixed(3)}` : `$${n.toFixed(2)}`);

async function keyInfo(): Promise<KeyInfo | undefined> {
	try {
		const res = await fetch(URL, { signal: AbortSignal.timeout(5000) });
		if (!res.ok) return undefined;
		return ((await res.json()) as { data?: KeyInfo }).data;
	} catch {
		return undefined;
	}
}

function keyLine(k: KeyInfo): string {
	const parts = [`today ${usd(k.usage_daily ?? 0)}`, `week ${usd(k.usage_weekly ?? 0)}`, `month ${usd(k.usage_monthly ?? 0)}`];
	if (k.limit != null && k.limit_remaining != null)
		parts.push(`${usd(k.limit_remaining)} of ${usd(k.limit)} left${k.limit_reset ? ` (${k.limit_reset})` : ""}`);
	return `OpenRouter ${parts.join(" · ")}`;
}

/** Split the billed total over input, output and cache by Pi's own estimate, or by tokens. */
function withCost(u: Usage, total: number): Usage {
	const est = u.cost ?? {};
	const keys = ["input", "output", "cacheRead", "cacheWrite"] as const;
	const base = keys.reduce((s, k) => s + (est[k] ?? 0), 0);
	const weights = base > 0 ? keys.map((k) => est[k] ?? 0) : keys.map((k) => u[k] ?? 0);
	const sum = weights.reduce((a, b) => a + b, 0) || 1;
	const cost: Record<string, number> = { total };
	keys.forEach((k, i) => (cost[k] = (total * weights[i]) / sum));
	return { ...u, cost };
}

export default function (pi: ExtensionAPI) {
	if (!ON) return;
	// The last billed cost seen on the stream, with the response id it came with.
	let billed: { id?: string; cost: number } | undefined;
	let lastFetch = 0;

	pi.on("provider_stream_event", (event) => {
		const d = event.data as { id?: string; usage?: { cost?: unknown } } | undefined;
		if (typeof d?.usage?.cost === "number") billed = { id: d.id, cost: d.usage.cost };
	});

	pi.on("message_end", (event) => {
		const m = event.message as Msg;
		if (m.role !== "assistant" || !billed || !m.usage) return;
		if (billed.id && m.responseId && billed.id !== m.responseId) return;
		const cost = billed.cost;
		billed = undefined;
		return { message: { ...m, usage: withCost(m.usage, cost) } as typeof event.message };
	});

	const refresh = async (ctx: { ui: { setStatus(key: string, text: string | undefined): void } }, force = false) => {
		if (!force && Date.now() - lastFetch < REFRESH_MS) return;
		lastFetch = Date.now();
		const k = await keyInfo();
		if (!k) return;
		// The fetch can outlive the session (`pi -p` exits right after its run), and a stale
		// ctx throws on .ui; with `void refresh(...)` that was an unhandled rejection.
		try {
			ctx.ui.setStatus("cost", keyLine(k));
		} catch {
			// session gone: nothing to show the status in
		}
	};
	pi.on("session_start", (_e, ctx) => void refresh(ctx, true));
	pi.on("agent_end", (_e, ctx) => void refresh(ctx));

	pi.registerCommand("usage", {
		description: "Cost: this session by model (billed by OpenRouter), and the OpenRouter key's totals",
		handler: async (_arg, ctx) => {
			const byModel = new Map<string, number>();
			for (const e of ctx.sessionManager.getEntries() as { type: string; message?: Msg }[]) {
				const m = e.message;
				if (e.type !== "message" || m?.role !== "assistant" || !m.usage) continue;
				byModel.set(m.model ?? "?", (byModel.get(m.model ?? "?") ?? 0) + (m.usage.cost?.total ?? 0));
			}
			const total = [...byModel.values()].reduce((a, b) => a + b, 0);
			const lines = [`This session: ${usd(total)}`];
			for (const [model, c] of [...byModel].sort((a, b) => b[1] - a[1])) lines.push(`  ${model}: ${usd(c)}`);
			lastFetch = 0;
			const k = await keyInfo();
			lines.push(k ? keyLine(k) : `OpenRouter totals unavailable (${URL})`);
			if (k) ctx.ui.setStatus("cost", keyLine(k));
			ctx.ui.notify(lines.join("\n"), "info");
		},
	});
}
