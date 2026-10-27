/**
 * Keep big tool output out of small context windows (our models have 32k per slot).
 *
 * - `read` without a limit reads PI_READ_LIMIT lines (default 150); Pi then says how to
 *   continue with offset.
 * - Any other tool result over PI_SPILL_CHARS is saved to a file (default 6000 chars, or 15%
 *   of the context window for big models: a 410k brain read a 21k digest in 25 pieces); the
 *   model gets a digest, the size and the path, and digs in with grep or read. The digest keeps the
 *   lines that matter in logs (errors, failures, panics and the lines after them) plus the
 *   start and end, and counts the rest: the old first-2000-chars preview cut off test
 *   failures, which come last. With PI_SQUEEZ_URL set, Squeez-2B (a model trained to pick
 *   the relevant lines of tool output, arXiv 2604.04979) picks them instead; PI_LOG_DIGEST=0
 *   goes back to the plain preview.
 * - Over-long `read` results (very long lines) are cut, pointing back at the source file.
 * - Digest lines are cut at 400 chars: a grep that matched a 95k-char string-array line once
 *   went through whole (it was among the last lines, which the digest always keeps) and
 *   filled a worker's context.
 *
 * Spill files live in $TMPDIR/pi-spill/<pid>/ and are removed after a day.
 */
import { mkdirSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const READ_LIMIT = Number(process.env.PI_READ_LIMIT) || 150;
const SPILL_CHARS = Number(process.env.PI_SPILL_CHARS) || 0;
/** Chars a result may have before it's cut or spilled: 6000 for our 32k models, more for big ones. */
const spillAt = (window: number | undefined) => SPILL_CHARS || Math.max(6000, Math.round((window ?? 0) * 0.15));
const ROOT = join(tmpdir(), "pi-spill");
const DIGEST = process.env.PI_LOG_DIGEST !== "0";
const SQUEEZ_URL = process.env.PI_SQUEEZ_URL;
/** Squeez reads at most this much (it was trained on up to 20k tokens; it runs on the CPU). */
const SQUEEZ_CHARS = 30000;
const DAY = 24 * 60 * 60 * 1000;

function sweep() {
	try {
		for (const name of readdirSync(ROOT)) {
			const dir = join(ROOT, name);
			if (Date.now() - statSync(dir).mtimeMs > DAY) rmSync(dir, { recursive: true, force: true });
		}
	} catch {
		/* nothing to clean */
	}
}

/** Failure markers of test runners and compilers (pytest, go test, cargo, unittest, node). */
const STRONG =
	/^\s*(--- FAIL|FAIL\b|FAILED\b|ERROR\b|E\s|error(\[E\d+\])?:|thread '.*' panicked|panic:|Traceback|\S+Error\b|AssertionError|assert)|\bFAILED\b|^\s*-->|^test result:|failures?:/;
/** Words that often matter but also show up in passing output ("no error"). */
const WEAK = /\b(error|errors|fail|failed|failure|panic|exception|warning|expected|cannot|undefined)\b/i;
const PASSING = /^\s*(ok\b|PASS\b|--- PASS|=== RUN|test \S+ \.\.\. ok|\S+ \.\.\. ok\b|PASSED\b|\S+::\S+ PASSED)/;

function render(all: string[], keep: Uint8Array): string {
	const out: string[] = [];
	let gap: string[] = [];
	const flush = () => {
		if (!gap.length) return;
		const passing = gap.filter((l) => PASSING.test(l)).length;
		out.push(`[... ${gap.length} lines${passing ? `, ${passing} passing` : ""} ...]`);
		gap = [];
	};
	all.forEach((l, i) => {
		if (keep[i]) {
			flush();
			out.push(l.length > 400 ? `${l.slice(0, 400)} [...]` : l);
		} else gap.push(l);
	});
	flush();
	return out.join("\n");
}

/**
 * The lines of a log worth reading, in order, with the gaps counted: the start and end, and
 * the lines around failure markers; around weaker words ("error", "warning") only if that
 * still fits in `max`.
 */
/** Longest line a digest shows: one minified or string-array line can be 95k chars on its own. */
const LINE_MAX = 400;
const clip = (l: string) => (l.length > LINE_MAX ? `${l.slice(0, LINE_MAX)} [... line cut: ${l.length} chars]` : l);

export function digest(text: string, max: number): string {
	const all = text.split("\n").map(clip);
	const mark = (keep: Uint8Array, re: RegExp, before: number, after: number) =>
		all.forEach((l, i) => {
			if (!re.test(l) || PASSING.test(l)) return;
			for (let j = Math.max(0, i - before); j <= Math.min(all.length - 1, i + after); j++) keep[j] = 1;
		});
	const keep = new Uint8Array(all.length);
	for (let i = 0; i < Math.min(5, all.length); i++) keep[i] = 1;
	for (let i = Math.max(0, all.length - 15); i < all.length; i++) keep[i] = 1;
	mark(keep, STRONG, 2, 8);
	const strong = render(all, keep);
	const withWeak = keep.slice();
	mark(withWeak, WEAK, 1, 3);
	const both = render(all, withWeak);
	if (both.length <= max) return both;
	if (strong.length <= max) return strong;
	// Too many failures: the first of them and the end of the log.
	const tail = all.slice(-15).join("\n");
	return `${strong.slice(0, max - tail.length - 60)}\n[... digest cut ...]\n${tail}`;
}

async function squeez(command: string, text: string): Promise<string | undefined> {
	if (!SQUEEZ_URL) return undefined;
	const input = text.length > SQUEEZ_CHARS ? digest(text, SQUEEZ_CHARS) : text;
	try {
		const res = await fetch(`${SQUEEZ_URL}/v1/chat/completions`, {
			method: "POST",
			signal: AbortSignal.timeout(90_000),
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify({
				temperature: 0.1,
				max_tokens: 1500,
				chat_template_kwargs: { enable_thinking: false },
				messages: [
					{
						role: "system",
						content:
							"You prune verbose tool output for a coding agent. Given a focused extraction query and one tool output, " +
							"return only the smallest verbatim evidence block(s) the agent should read next. Return the kept text inside " +
							"<relevant_lines> tags. Do not rewrite, summarize, or invent lines.",
					},
					{
						role: "user",
						content: `<query>\nFind the errors, failing tests and result summary in the output of \`${command}\`\n</query>\n<tool_output>\n${input}\n</tool_output>`,
					},
				],
			}),
		});
		if (!res.ok) return undefined;
		const reply: string = (await res.json()).choices?.[0]?.message?.content ?? "";
		const kept = reply.match(/<relevant_lines>\n?([\s\S]*?)\n?<\/relevant_lines>/)?.[1];
		return kept === undefined ? undefined : kept.trim() || "(nothing relevant found)";
	} catch {
		return undefined;
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", () => sweep());

	pi.on("tool_call", (event) => {
		if (event.toolName === "read" && event.input.limit === undefined) event.input.limit = READ_LIMIT;
	});

	pi.on("tool_result", async (event, ctx) => {
		const texts = event.content.filter((c) => c.type === "text") as { type: "text"; text: string }[];
		const text = texts.map((c) => c.text).join("\n");
		const limit = spillAt(ctx.model?.contextWindow);
		if (text.length <= limit) return;
		const images = event.content.filter((c) => c.type !== "text");
		const lines = text.split("\n").length;

		if (event.toolName === "read") {
			const path = String(event.input.path ?? "");
			const cut = text.slice(0, limit);
			return {
				content: [
					...images,
					{
						type: "text",
						text: `${cut}\n\n[Cut at ${limit} of ${text.length} chars. Use grep on ${path}, or read it with a smaller offset/limit.]`,
					},
				],
				structuredContent: event.structuredContent,
			};
		}

		const dir = join(ROOT, String(process.pid));
		mkdirSync(dir, { recursive: true, mode: 0o700 });
		const file = join(dir, `${event.toolName.replace(/[^\w-]/g, "_")}-${event.toolCallId.replace(/[^\w-]/g, "_")}.txt`);
		writeFileSync(file, text, { mode: 0o600 });
		const command = String(event.input.command ?? event.toolName);
		const picked = DIGEST ? await squeez(command, text) : undefined;
		const shown = picked ?? (DIGEST ? digest(text, limit / 2) : text.slice(0, Math.min(2000, Math.floor(limit / 3))));
		const how = picked ? "Lines picked by Squeez" : DIGEST ? "Digest" : "Start";
		return {
			content: [
				...images,
				{
					type: "text",
					text:
						`${shown}\n\n[${how} of a long output: ${text.length} chars, ${lines} lines. ` +
						`Full output saved to ${file}. Use grep on that file to find what you need, then read with offset/limit.]`,
				},
			],
			structuredContent: event.structuredContent,
		};
	});
}
