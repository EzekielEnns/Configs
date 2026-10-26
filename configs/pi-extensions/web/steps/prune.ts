/**
 * Rerank BM25's candidate chunks with Open Provence and keep only the sentences that answer
 * the question, through the evidence service's `/prune` (ai-stack docs/RAG-PLAN.md). On by
 * setting PI_EVIDENCE_URL; without it, or when the service fails, BM25's pick stands.
 *
 * A chunk's score is its best sentence's probability; chunks under the cutoff are dropped,
 * so a page that doesn't answer the question gives nothing rather than its nearest keywords.
 */
import type { Scored } from "./rank.js";

export const EVIDENCE_URL = process.env.PI_EVIDENCE_URL;
/** Candidates BM25 hands to Provence per page. */
export const CANDIDATES = 8;
const CUTOFF = Number(process.env.PI_EVIDENCE_CUTOFF) || 0.3;

interface Pruned {
	best: number;
	kept: { text: string; prob: number }[];
}

export async function prune(question: string, chunks: Scored[], top: number, signal: AbortSignal): Promise<Scored[]> {
	const pruned = await Promise.all(
		chunks.map(async (c) => {
			const res = await fetch(`${EVIDENCE_URL}/prune`, {
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
