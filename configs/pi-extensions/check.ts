/**
 * Compile errors right after the edit that caused them (ai-stack docs/CODING-PLAN.md step 2).
 *
 * In the Flint bake-off it found compile errors late, in a wall from `cargo test` after
 * another whole-file rewrite, and one Go run spent 15 minutes on its own wrong field names.
 * SWE-agent's lint-gated edit: 15.0% → 18.0% solved.
 *
 * tool_result: after a successful `write` or `edit` of a source file, run the project's
 * fast check and append its errors (at most MAX_LINES), or "ok". Warnings are left out.
 *   Rust (Cargo.toml)  cargo check --all-targets --message-format=short
 *   Go (go.mod)        go vet ./...   (type-checks tests too)
 *   Python             ruff check --select E9,F63,F7,F82 (syntax, undefined names), else py_compile
 * PI_CHECK=0 turns it off.
 */
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, extname, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ON = process.env.PI_CHECK !== "0";
const MAX_LINES = 20;
const TIMEOUT = 90_000;

/** Nearest folder at or above `from` (inside `root`) holding `marker`. */
function findUp(from: string, root: string, marker: string): string | undefined {
	for (let d = from; d.startsWith(root); d = dirname(d)) {
		if (existsSync(resolve(d, marker))) return d;
		if (d === dirname(d)) break;
	}
	return undefined;
}

function run(cmd: string, args: string[], cwd: string): Promise<{ ok: boolean; out: string }> {
	return new Promise((done) =>
		execFile(cmd, args, { cwd, timeout: TIMEOUT, maxBuffer: 4 << 20 }, (err, stdout, stderr) => {
			if (err && (err as NodeJS.ErrnoException).code === "ENOENT") return done({ ok: true, out: "" });
			done({ ok: !err, out: `${stdout}${stderr}` });
		}),
	);
}

async function check(file: string, root: string): Promise<{ name: string; errors: string[] } | undefined> {
	const ext = extname(file);
	const errorLines = (out: string, re: RegExp) => out.split("\n").filter((l) => re.test(l));
	if (ext === ".rs") {
		const crate = findUp(dirname(file), root, "Cargo.toml");
		if (!crate) return undefined;
		const r = await run("cargo", ["check", "--quiet", "--all-targets", "--message-format=short"], crate);
		return { name: "cargo check", errors: r.ok ? [] : errorLines(r.out, /\berror\b/).filter((l) => !/could not compile|^error: aborting/.test(l)) };
	}
	if (ext === ".go") {
		const mod = findUp(dirname(file), root, "go.mod");
		if (!mod) return undefined;
		const r = await run("go", ["vet", "./..."], mod);
		return { name: "go vet", errors: r.ok ? [] : errorLines(r.out, /^\S+\.go:\d+|^#|^vet:/) };
	}
	if (ext === ".py") {
		const r = await run("ruff", ["check", "--quiet", "--output-format=concise", "--select", "E9,F63,F7,F82", file], root);
		if (r.out || !r.ok) return { name: "ruff (syntax, undefined names)", errors: r.ok ? [] : errorLines(r.out, /:\d+:\d+:/) };
		const c = await run("python3", ["-m", "py_compile", file], root);
		return { name: "py_compile", errors: c.ok ? [] : c.out.trim().split("\n") };
	}
	return undefined;
}

export default function (pi: ExtensionAPI) {
	if (!ON) return;
	pi.on("tool_result", async (event, ctx) => {
		if ((event.toolName !== "write" && event.toolName !== "edit") || event.isError) return;
		const file = resolve(ctx.cwd, String(event.input.path ?? ""));
		const result = await check(file, ctx.cwd);
		if (!result) return;
		const { name, errors } = result;
		const shown = errors.slice(0, MAX_LINES);
		const more = errors.length > MAX_LINES ? `\n[... ${errors.length - MAX_LINES} more]` : "";
		const text = errors.length
			? `\n[${name}: ${errors.length} error line(s); fix these first]\n${shown.join("\n")}${more}`
			: `\n[${name}: ok]`;
		return { content: [...event.content, { type: "text", text }] };
	});
}
