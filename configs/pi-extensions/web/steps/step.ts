/**
 * Steps: small typed functions a tool chains together (ai-stack docs/HELPERS.md). A step
 * that fails or runs over its time budget returns its passthrough instead, so a missing
 * helper model makes a pipeline slower or rougher, never broken. Every run appends one
 * trace line, which is how evals see where time goes.
 *
 * No Pi imports here: this folder moves to its own repo as is.
 */
import { appendFileSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const TRACE_DIR = process.env.PI_RESEARCH_DIR ?? join(tmpdir(), "pi-web");

export interface TraceLine {
	step: string;
	ms: number;
	ok: boolean;
	passthrough?: boolean;
	error?: string;
	[k: string]: unknown;
}

export function trace(line: TraceLine) {
	try {
		mkdirSync(TRACE_DIR, { recursive: true, mode: 0o700 });
		appendFileSync(join(TRACE_DIR, "trace.jsonl"), `${JSON.stringify({ time: new Date().toISOString(), ...line })}\n`);
	} catch {
		/* tracing never breaks a tool */
	}
}

/**
 * Run `fn` within `budgetMs`. On error or timeout, return `fallback()` and trace why.
 * `info` adds fields to the trace line from the result (sizes, counts, model).
 */
export async function runStep<T>(
	name: string,
	budgetMs: number,
	fn: (signal: AbortSignal) => Promise<T>,
	fallback: () => T,
	info: (out: T) => Record<string, unknown> = () => ({}),
): Promise<T> {
	const start = Date.now();
	const controller = new AbortController();
	const timer = setTimeout(() => controller.abort(new Error(`over budget (${budgetMs} ms)`)), budgetMs);
	try {
		const out = await Promise.race([
			fn(controller.signal),
			new Promise<never>((_, reject) =>
				controller.signal.addEventListener("abort", () => reject(controller.signal.reason), { once: true }),
			),
		]);
		trace({ step: name, ms: Date.now() - start, ok: true, ...info(out) });
		return out;
	} catch (err) {
		const out = fallback();
		trace({ step: name, ms: Date.now() - start, ok: false, passthrough: true, error: String((err as Error)?.message ?? err), ...info(out) });
		return out;
	} finally {
		clearTimeout(timer);
	}
}
