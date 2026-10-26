/**
 * Keep big tool output out of small context windows (our models have 32k per slot).
 *
 * - `read` without a limit reads PI_READ_LIMIT lines (default 150); Pi then says how to
 *   continue with offset.
 * - Any other tool result over PI_SPILL_CHARS (default 6000) is saved to a file; the model
 *   gets the first part, the size and the path, and digs in with grep or read.
 * - Over-long `read` results (very long lines) are cut, pointing back at the source file.
 *
 * Spill files live in $TMPDIR/pi-spill/<pid>/ and are removed after a day.
 */
import { mkdirSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const READ_LIMIT = Number(process.env.PI_READ_LIMIT) || 150;
const SPILL_CHARS = Number(process.env.PI_SPILL_CHARS) || 6000;
const PREVIEW_CHARS = Math.min(2000, Math.floor(SPILL_CHARS / 3));
const ROOT = join(tmpdir(), "pi-spill");
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

export default function (pi: ExtensionAPI) {
	pi.on("session_start", () => sweep());

	pi.on("tool_call", (event) => {
		if (event.toolName === "read" && event.input.limit === undefined) event.input.limit = READ_LIMIT;
	});

	pi.on("tool_result", (event) => {
		const texts = event.content.filter((c) => c.type === "text") as { type: "text"; text: string }[];
		const text = texts.map((c) => c.text).join("\n");
		if (text.length <= SPILL_CHARS) return;
		const images = event.content.filter((c) => c.type !== "text");
		const lines = text.split("\n").length;

		if (event.toolName === "read") {
			const path = String(event.input.path ?? "");
			const cut = text.slice(0, SPILL_CHARS);
			return {
				content: [
					...images,
					{
						type: "text",
						text: `${cut}\n\n[Cut at ${SPILL_CHARS} of ${text.length} chars. Use grep on ${path}, or read it with a smaller offset/limit.]`,
					},
				],
				structuredContent: event.structuredContent,
			};
		}

		const dir = join(ROOT, String(process.pid));
		mkdirSync(dir, { recursive: true, mode: 0o700 });
		const file = join(dir, `${event.toolName.replace(/[^\w-]/g, "_")}-${event.toolCallId.replace(/[^\w-]/g, "_")}.txt`);
		writeFileSync(file, text, { mode: 0o600 });
		return {
			content: [
				...images,
				{
					type: "text",
					text:
						`${text.slice(0, PREVIEW_CHARS)}\n\n[Output too long for context: ${text.length} chars, ${lines} lines. ` +
						`Full output saved to ${file}. Use grep on that file to find what you need, then read with offset/limit.]`,
				},
			],
			structuredContent: event.structuredContent,
		};
	});
}
