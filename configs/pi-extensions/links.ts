/**
 * In Rex, ask the model to write code locations as nvim-open:// markdown links: Pi renders
 * markdown links as terminal hyperlinks there, and a click opens the file at that line in
 * Neovim in the same tab (configs/nvim-open). Outside Rex, and for models with small
 * windows (Flint, Sage), it adds nothing.
 */
import { hostname } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SESSION = process.env.REX_SESSION;
const BLOCK = process.env.REX_BLOCK;

export default function (pi: ExtensionAPI) {
	if (!SESSION || !BLOCK) return;
	const base =
		`nvim-open://open?host=${encodeURIComponent(hostname().split(".")[0])}` +
		`&session=${encodeURIComponent(SESSION)}&block=${encodeURIComponent(BLOCK)}`;
	const note =
		"# Code links\n" +
		"The user reads your replies in a terminal that opens nvim-open:// links in their editor. When you point at " +
		"a specific line of a file, write it as a markdown link with the path and line as its text and this target, " +
		"adding the line and the absolute path (spaces as %20):\n" +
		`[src/app.ts:42](${base}&line=42&file=/abs/path/src/app.ts)\n` +
		"Plain paths are fine for whole files or long lists of files.";
	pi.on("before_agent_start", (event, ctx) => {
		if ((ctx.model?.contextWindow ?? 0) <= 32768) return;
		return { systemPrompt: `${event.systemPrompt}\n\n${note}` };
	});
}
