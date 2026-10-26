/**
 * Pick the chunks that answer a question. Today: BM25 keyword scoring, no model, instant.
 * Phase B replaces it with Open Provence (rerank + sentence pruning) through `ai-helpers`,
 * with this as the passthrough.
 */
import type { Chunk } from "./chunk.js";

export interface Scored extends Chunk {
	score: number;
}

const STOP = new Set(
	"a an and are as at be by can do does for from has have how i in is it its my of on or so that the this to was what when where which who why will with you your".split(" "),
);

export function terms(text: string): string[] {
	return (text.toLowerCase().match(/[\p{L}\p{N}][\p{L}\p{N}._+#-]*/gu) ?? []).filter((t) => !STOP.has(t) && t.length > 1);
}

/** BM25 (k1 1.2, b 0.75) over the chunks, with the heading counted as part of the text. */
export function rank(question: string, chunks: Chunk[], top = 3): Scored[] {
	const q = [...new Set(terms(question))];
	if (!q.length || !chunks.length) return chunks.slice(0, top).map((c) => ({ ...c, score: 0 }));
	const docs = chunks.map((c) => terms(`${c.heading} ${c.text}`));
	const avg = docs.reduce((s, d) => s + d.length, 0) / docs.length || 1;
	const df = new Map(q.map((t) => [t, docs.filter((d) => d.includes(t)).length]));
	const scored = chunks.map((c, i) => {
		const d = docs[i];
		let score = 0;
		for (const t of q) {
			const tf = d.filter((x) => x === t).length;
			if (!tf) continue;
			const idf = Math.log(1 + (docs.length - df.get(t)! + 0.5) / (df.get(t)! + 0.5));
			score += (idf * tf * 2.2) / (tf + 1.2 * (0.25 + (0.75 * d.length) / avg));
		}
		return { ...c, score };
	});
	return scored
		.filter((c) => c.score > 0)
		.sort((a, b) => b.score - a.score)
		.slice(0, top)
		.sort((a, b) => a.startLine - b.startLine); // keep reading order
}
