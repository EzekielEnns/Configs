/**
 * The evidence service's `/evidence` (ai-stack docs/RAG-PLAN.md): search, fetch 2-3 pages,
 * extract, chunk, BM25 and Open Provence in one call on the desktop, returning the passages
 * that answer a question with their URLs and scores, and `enough` when the best one does.
 * `lookup` uses it first and falls back to doing the same steps here when it fails.
 */
export interface Passage {
	url: string;
	title: string;
	heading: string;
	text: string;
	score: number | null;
}

export interface Evidence {
	passages: Passage[];
	enough: boolean;
	best: number;
	queries: string[];
	sources: { url: string; status: string }[];
	ms: number;
}

export async function evidence(base: string, question: string, query: string | undefined, signal: AbortSignal): Promise<Evidence> {
	const res = await fetch(`${base}/evidence`, {
		method: "POST",
		signal,
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify({ question, ...(query ? { query } : {}) }),
	});
	if (!res.ok) throw new Error(`/evidence returned ${res.status}`);
	const out = (await res.json()) as Evidence;
	if (!out.passages?.length) throw new Error("no passages");
	return out;
}
