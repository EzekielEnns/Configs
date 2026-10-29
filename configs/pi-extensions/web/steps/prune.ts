/**
 * Rerank BM25's candidate chunks with Open Provence and keep only the sentences that answer
 * the question, through the evidence service's `/prune` (ai-stack docs/RAG-PLAN.md). The
 * service is the gateway's host on port 8090 unless PI_EVIDENCE_URL says otherwise
 * (PI_EVIDENCE_URL=0 turns it off); when it fails, BM25's pick stands.
 *
 * A chunk's score is its best sentence's probability; chunks under the cutoff are dropped,
 * so a page that doesn't answer the question gives nothing rather than its nearest keywords.
 */
import type { Scored } from "./rank.js";

/** The evidence service's base URL, or undefined when it's off. */
export function evidenceUrl(gatewayUrl?: string): string | undefined {
	const env = process.env.PI_EVIDENCE_URL;
	if (env === "0" || env === "off") return undefined;
	if (env) return env.replace(/\/+$/, "");
	if (!gatewayUrl) return undefined;
	const u = new URL(gatewayUrl);
	u.port = "8090";
	return u.origin;
}
/** Candidates BM25 hands to Provence per page. */
export const CANDIDATES = 8;
const CUTOFF = Number(process.env.PI_EVIDENCE_CUTOFF) || 0.3;

interface Pruned {
	best: number;
	kept: { text: string; prob: number }[];
}

export async function prune(
	base: string,
	question: string,
	chunks: Scored[],
	top: number,
	signal: AbortSignal,
): Promise<Scored[]> {
	const pruned = await Promise.all(
		chunks.map(async (c) => {
			const res = await fetch(`${base}/prune`, {
				method: "POST",
				signal,
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify({ question, text: c.text, mode: "text" }),
			});
			if (!res.ok) throw new Error(`/prune returned ${res.status}`);
			const p = (await res.json()) as Pruned;
			return { ...c, score: p.best, text: p.kept.map((k) => k.text).join("").trim() };
		}),
	);
	return pruned
		.filter((c) => c.score >= CUTOFF && c.text)
		.sort((a, b) => b.score - a.score)
		.slice(0, top)
		.sort((a, b) => a.startLine - b.startLine);
}
