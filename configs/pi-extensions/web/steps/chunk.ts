/**
 * Split a saved page into ~300-token chunks along its structure (headings, then blank
 * lines), keeping each chunk's heading and line range so the agent can read around it.
 */
export interface Chunk {
	heading: string;
	startLine: number; // 1-based, in the saved file
	endLine: number;
	text: string;
}

const TARGET_CHARS = 1200; // ~300 tokens
const MAX_CHARS = 2000;

export function chunk(body: string): Chunk[] {
	const lines = body.split("\n");
	const chunks: Chunk[] = [];
	let heading = "";
	let buf: string[] = [];
	let start = 1;
	let inFence = false;

	const flush = (end: number) => {
		const text = buf.join("\n").trim();
		if (text) chunks.push({ heading, startLine: start, endLine: end, text });
		buf = [];
	};

	lines.forEach((line, i) => {
		const n = i + 1;
		if (line.startsWith("```")) inFence = !inFence;
		const isHeading = !inFence && /^#{1,6} \S/.test(line);
		const size = buf.reduce((s, l) => s + l.length + 1, 0);
		// New chunk at a heading, at a paragraph break once big enough, or when too big.
		if (isHeading || (!inFence && line.trim() === "" && size >= TARGET_CHARS) || size + line.length > MAX_CHARS) {
			flush(n - 1);
			start = n;
		}
		if (isHeading) heading = line.replace(/^#+\s*/, "").slice(0, 100);
		if (buf.length || line.trim()) buf.push(line);
		else start = n + 1;
	});
	flush(lines.length);
	return chunks;
}
