/**
 * Search providers, tried in order until one returns results:
 *   gateway:<tool>  LiteLLM's /v1/search/<tool> on the desktop (Brave, SearXNG, ...); API
 *                   keys stay in the desktop's secrets.env, never on this machine
 *   searxng         SearXNG directly, with its engines pinned (Yahoo answers from a home IP)
 * The order comes from ~/.pi/searxng.json `searchChain`.
 */
import { runStep } from "./step.js";

export interface Result {
	title: string;
	url: string;
	snippet: string;
	date?: string;
	source: string;
}

export interface SearchConfig {
	searxngUrl: string;
	searxngEngines?: string;
	gatewayUrl?: string;
	searchChain?: string[];
}

const BUDGET_MS = 15_000;
const clean = (s: unknown) => String(s ?? "").replace(/\s+/g, " ").trim();

async function gateway(cfg: SearchConfig, tool: string, query: string, max: number, signal: AbortSignal): Promise<Result[]> {
	if (!cfg.gatewayUrl) throw new Error("no gatewayUrl");
	const res = await fetch(`${cfg.gatewayUrl}/v1/search/${tool}`, {
		method: "POST",
		signal,
		headers: { "Content-Type": "application/json", Authorization: "Bearer local" },
		body: JSON.stringify({ query, max_results: max }),
	});
	if (!res.ok) throw new Error(`gateway ${tool}: HTTP ${res.status}`);
	const data: any = await res.json();
	return (data.results ?? []).map((r: any) => ({
		title: clean(r.title) || "Untitled",
		url: String(r.url),
		snippet: clean(r.snippet),
		date: r.date ? String(r.date).slice(0, 10) : undefined,
		source: tool,
	}));
}

async function searxng(cfg: SearchConfig, query: string, max: number, signal: AbortSignal): Promise<Result[]> {
	const url = new URL(`${cfg.searxngUrl}/search`);
	url.searchParams.set("q", query);
	url.searchParams.set("format", "json");
	if (cfg.searxngEngines) url.searchParams.set("engines", cfg.searxngEngines);
	const res = await fetch(url, { signal, headers: { Accept: "application/json" } });
	if (!res.ok) throw new Error(`SearXNG: HTTP ${res.status}`);
	const data: any = await res.json();
	return (data.results ?? []).slice(0, max).map((r: any) => ({
		title: clean(r.title) || "Untitled",
		url: String(r.url),
		snippet: clean(r.content),
		date: r.publishedDate ? String(r.publishedDate).slice(0, 10) : undefined,
		source: "searxng",
	}));
}

/** First provider in the chain that returns results; [] if none do. */
export async function search(cfg: SearchConfig, query: string, max = 8): Promise<Result[]> {
	const chain = cfg.searchChain?.length ? cfg.searchChain : ["searxng"];
	for (const provider of chain) {
		const results = await runStep(
			`search:${provider}`,
			BUDGET_MS,
			(signal) =>
				provider.startsWith("gateway:")
					? gateway(cfg, provider.slice(8), query, max, signal)
					: searxng(cfg, query, max, signal),
			() => [] as Result[],
			(out) => ({ query, results: out.length }),
		);
		if (results.length) return dedupe(results).slice(0, max);
	}
	return [];
}

function dedupe(results: Result[]): Result[] {
	const seen = new Set<string>();
	return results.filter((r) => {
		const key = r.url.replace(/[#?].*$/, "").replace(/\/$/, "");
		if (seen.has(key)) return false;
		seen.add(key);
		return true;
	});
}
