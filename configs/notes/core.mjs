/**
 * Shared notes vault: the rules every way in uses (Pi's notes tools, the pis broker, the
 * Claude Code MCP server, the `notes` CLI). Node built-ins only.
 *
 * - The vault is NOTES_DIR (default ~/Notes), synced by Syncthing between the machines and
 *   phones. Reads: anything in it but sync/app internals. Writes: never the folders in
 *   NOTES_PROTECTED (default Personal,Wife), nor AGENTS.md or dot-folders, whatever a grant says.
 * - A write is a plan (path, mode, the file before and after, a diff), applied only if the file
 *   still matches what the plan was made from, so it never clobbers an edit synced meanwhile.
 * - State lives outside the vault, in ~/.local/state/notes: grants.json (files approved with
 *   "always", for every project) and outbox/ (writes nobody could approve, for `notes review`).
 *   The pis sandbox can read this folder but not write it.
 */
import { createHash, randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import {
	existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, realpathSync, renameSync, rmSync, statSync,
	writeFileSync,
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import { dirname, join, relative, resolve, sep } from "node:path";

export const VAULT = resolve(process.env.NOTES_DIR || join(homedir(), "Notes"));
export const STATE = resolve(process.env.NOTES_STATE || join(homedir(), ".local", "state", "notes"));
export const GRANTS = join(STATE, "grants.json");
export const OUTBOX = join(STATE, "outbox");
export const PROTECTED = (process.env.NOTES_PROTECTED ?? "Personal,Wife").split(",").map((s) => s.trim()).filter(Boolean);
const HIDDEN = /(^|\/)(\.git|\.obsidian|\.stfolder|\.stversions|\.trash)(\/|$)|(^|\/)\.st(ignore|globalignore)$/;
const MAX_NOTE = 1_000_000; // bytes: a note, not a dataset

export const sha = (s) => createHash("sha256").update(s ?? "").digest("hex");

/** A vault-relative path, checked: inside the vault after resolving symlinks, not hidden. */
export function notePath(rel) {
	const clean = String(rel ?? "").replace(/^\/+/, "").replace(/^~\/Notes\//, "");
	const abs = resolve(VAULT, clean);
	if (abs !== VAULT && !abs.startsWith(VAULT + sep)) throw new Error(`${rel}: outside the vault`);
	const relPath = relative(VAULT, abs);
	if (!relPath || HIDDEN.test(relPath)) throw new Error(`${rel}: not a note`);
	// The deepest part that exists must resolve inside the vault too (no symlink out).
	let probe = abs;
	while (!existsSync(probe) && probe !== VAULT) probe = dirname(probe);
	if (existsSync(VAULT)) {
		const real = realpathSync(probe);
		const vaultReal = realpathSync(VAULT);
		if (real !== vaultReal && !real.startsWith(vaultReal + sep)) throw new Error(`${rel}: leads outside the vault`);
	}
	return { abs, rel: relPath };
}

/** Why a vault path can't be written, or null. */
export function writeBlock(rel) {
	const top = rel.split("/")[0];
	if (PROTECTED.includes(top)) return `${top}/ is the user's own notes: agents may read it, never write it`;
	if (rel === "AGENTS.md") return "AGENTS.md holds the vault's rules and is managed by the user";
	if (!/\.(md|txt)$/i.test(rel)) return "only .md and .txt notes can be written";
	return null;
}

function walk(dir, out = []) {
	for (const e of readdirSync(dir, { withFileTypes: true })) {
		const p = join(dir, e.name);
		const rel = relative(VAULT, p);
		if (HIDDEN.test(rel) || e.name.startsWith(".")) continue;
		if (e.isDirectory()) walk(p, out);
		else if (e.isFile()) out.push(rel);
	}
	return out;
}

/** Ripgrep over the vault: [{path, line, text}], at most `limit`. */
export function search(query, { folder = "", limit = 40, regex = false } = {}) {
	if (!existsSync(VAULT)) return [];
	const root = folder ? notePath(folder).abs : VAULT;
	const args = ["--json", "-i", "--max-count", "5", "--max-columns", "300", "-g", "!.git", "-g", "!.obsidian", "-g", "!.st*"];
	if (!regex) args.push("-F");
	args.push("--", String(query), root);
	const p = spawnSync(process.env.NOTES_RG || "rg", args, { encoding: "utf8", maxBuffer: 32 << 20 });
	const hits = [];
	for (const line of (p.stdout ?? "").split("\n")) {
		if (!line) continue;
		const m = JSON.parse(line);
		if (m.type !== "match") continue;
		hits.push({ path: relative(VAULT, m.data.path.text), line: m.data.line_number, text: m.data.lines.text.trim().slice(0, 300) });
		if (hits.length >= limit) break;
	}
	return hits;
}

/** A note's text, by line range (1-based). */
export function read(rel, { offset = 1, limit = 400 } = {}) {
	const { abs, rel: r } = notePath(rel);
	if (!existsSync(abs)) throw new Error(`${r}: no such note`);
	if (statSync(abs).isDirectory()) return { path: r, text: walk(abs).map((f) => relative(r, f)).sort().join("\n"), lines: 0 };
	if (statSync(abs).size > MAX_NOTE) throw new Error(`${r}: too big for a note`);
	const all = readFileSync(abs, "utf8").split("\n");
	const from = Math.max(1, offset);
	return { path: r, text: all.slice(from - 1, from - 1 + limit).join("\n"), lines: all.length, from };
}

/** Most recently changed notes: [{path, modified}]. */
export function recent({ folder = "", limit = 20 } = {}) {
	if (!existsSync(VAULT)) return [];
	const root = folder ? notePath(folder).abs : VAULT;
	return walk(root)
		.map((rel) => ({ path: rel, mtime: statSync(join(VAULT, rel)).mtimeMs }))
		.sort((a, b) => b.mtime - a.mtime)
		.slice(0, limit)
		.map(({ path, mtime }) => ({ path, modified: new Date(mtime).toISOString().slice(0, 16).replace("T", " ") }));
}

/** Unified diff of two texts (diff -u on temp files). */
export function diff(before, after, label) {
	const d = join(process.env.TMPDIR || tmpdir(), `notes-diff-${randomUUID()}`);
	mkdirSync(d, { recursive: true });
	try {
		writeFileSync(join(d, "a"), before);
		writeFileSync(join(d, "b"), after);
		const p = spawnSync(process.env.NOTES_DIFF || "diff", ["-u", "--label", `a/${label}`, "--label", `b/${label}`, join(d, "a"), join(d, "b")], { encoding: "utf8" });
		return p.stdout || "";
	} finally {
		rmSync(d, { recursive: true, force: true });
	}
}

/**
 * A write plan: mode create (new file only), append, or replace (whole file, or `old` -> text
 * for one exact, unique passage). Throws on anything the rules don't allow.
 */
export function plan({ path, mode, text, old }) {
	const { abs, rel } = notePath(path);
	const why = writeBlock(rel);
	if (why) throw new Error(`${rel}: ${why}`);
	if (typeof text !== "string") throw new Error("text is required");
	const exists = existsSync(abs);
	if (exists && lstatSync(abs).isSymbolicLink()) throw new Error(`${rel}: is a link`);
	const before = exists ? readFileSync(abs, "utf8") : "";
	let after;
	if (mode === "create") {
		if (exists) throw new Error(`${rel}: already exists (append or replace instead)`);
		after = text.endsWith("\n") ? text : `${text}\n`;
	} else if (mode === "append") {
		const sepText = before && !before.endsWith("\n") ? "\n" : "";
		after = before + sepText + (text.endsWith("\n") ? text : `${text}\n`);
	} else if (mode === "replace") {
		if (!exists) throw new Error(`${rel}: no such note (create it instead)`);
		if (old !== undefined && old !== null && old !== "") {
			const n = before.split(old).length - 1;
			if (n !== 1) throw new Error(`${rel}: the passage to replace occurs ${n} times, not once`);
			after = before.replace(old, () => text);
		} else after = text.endsWith("\n") ? text : `${text}\n`;
	} else throw new Error(`mode must be create, append or replace`);
	if (Buffer.byteLength(after) > MAX_NOTE) throw new Error(`${rel}: too big for a note`);
	return { path: rel, mode, exists, beforeHash: sha(exists ? before : null), after, diff: diff(before, after, rel) };
}

/** Apply a plan if the file hasn't changed since; atomic (write then rename). */
export function apply(p) {
	const { abs, rel } = notePath(p.path);
	const why = writeBlock(rel);
	if (why) throw new Error(`${rel}: ${why}`);
	const exists = existsSync(abs);
	if (exists && lstatSync(abs).isSymbolicLink()) throw new Error(`${rel}: is a link`);
	const now = sha(exists ? readFileSync(abs, "utf8") : null);
	if (now !== p.beforeHash) throw new Error(`${rel}: changed since the write was planned; plan it again`);
	mkdirSync(dirname(abs), { recursive: true });
	notePath(rel); // the folders just made must still be inside the vault
	const tmp = join(dirname(abs), `.${randomUUID()}.tmp`);
	writeFileSync(tmp, p.after);
	renameSync(tmp, abs);
	return rel;
}

export function grants() {
	try {
		const g = JSON.parse(readFileSync(GRANTS, "utf8"));
		return Array.isArray(g.files) ? g : { files: [] };
	} catch {
		return { files: [] };
	}
}

export const granted = (rel) => grants().files.some((f) => f.path === rel);

export function grant(rel, source) {
	if (writeBlock(rel)) return;
	const g = grants();
	if (!g.files.some((f) => f.path === rel)) g.files.push({ path: rel, since: new Date().toISOString().slice(0, 10), source });
	mkdirSync(STATE, { recursive: true });
	writeFileSync(GRANTS, `${JSON.stringify(g, null, 2)}\n`);
}

export function revoke(rel) {
	const g = grants();
	const n = g.files.length;
	g.files = g.files.filter((f) => f.path !== rel);
	mkdirSync(STATE, { recursive: true });
	writeFileSync(GRANTS, `${JSON.stringify(g, null, 2)}\n`);
	return n !== g.files.length;
}

/** Queue a write for `notes review`: {id, created, source, path, mode, text, old, diff}. */
export function queue(req, dir = OUTBOX) {
	mkdirSync(dir, { recursive: true });
	const id = `${new Date().toISOString().replace(/[:.]/g, "-")}-${randomUUID().slice(0, 8)}`;
	writeFileSync(join(dir, `${id}.json`), `${JSON.stringify({ id, created: new Date().toISOString(), ...req }, null, 2)}\n`);
	return id;
}

export function outbox() {
	if (!existsSync(OUTBOX)) return [];
	return readdirSync(OUTBOX)
		.filter((f) => f.endsWith(".json"))
		.sort()
		.map((f) => {
			try {
				return JSON.parse(readFileSync(join(OUTBOX, f), "utf8"));
			} catch {
				return null;
			}
		})
		.filter(Boolean);
}

export const dropQueued = (id) => rmSync(join(OUTBOX, `${id}.json`), { force: true });
