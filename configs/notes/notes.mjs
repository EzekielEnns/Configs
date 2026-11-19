#!/usr/bin/env node
/**
 * notes: the user's side of the notes vault (configs/notes/core.mjs).
 *
 *   notes review                 walk the outbox: each queued agent write as a diff, then
 *                                [a]pply, apply and [A]lways allow that file, [r]eject, [s]kip
 *   notes outbox [--json]        list queued writes (with fresh diffs in --json)
 *   notes apply ID [--always]    apply one queued write (Neovim's :Notes review uses these)
 *   notes reject ID
 *   notes grant PATH             let agents write PATH without asking; a PATH ending in / is a
 *                                whole folder (e.g. Agents/), every note under it
 *   notes grants [--json]        files and folders agents may write without asking
 *   notes revoke PATH            take one back
 *   notes path                   print the vault's folder
 */
import { createInterface } from "node:readline/promises";
import * as notes from "./core.mjs";

const [cmd, ...args] = process.argv.slice(2);
const json = args.includes("--json");
const fresh = (q) => {
	try {
		return { plan: notes.plan({ path: q.path, mode: q.mode, text: q.text, old: q.old ?? undefined }) };
	} catch (e) {
		return { error: e.message };
	}
};

function applyQueued(q, always) {
	const { plan, error } = fresh(q);
	if (error) throw new Error(error);
	const written = notes.apply(plan);
	if (always) notes.grant(written, `review of ${q.source ?? "an agent"}`);
	notes.dropQueued(q.id);
	return written;
}

const byId = (id) => {
	const q = notes.outbox().find((x) => x.id === id);
	if (!q) throw new Error(`no queued write ${id}`);
	return q;
};

try {
	if (cmd === "path") console.log(notes.VAULT);
	else if (cmd === "outbox") {
		const items = notes.outbox().map((q) => {
			const f = fresh(q);
			return { id: q.id, created: q.created, source: q.source, path: q.path, mode: q.mode, diff: f.plan?.diff ?? "", error: f.error };
		});
		if (json) console.log(JSON.stringify(items));
		else for (const q of items) console.log(`${q.id}  ${q.mode.padEnd(7)} ${q.path}  (${q.source ?? "?"})${q.error ? `  ! ${q.error}` : ""}`);
	} else if (cmd === "apply") console.log(`wrote ${applyQueued(byId(args[0]), args.includes("--always"))}`);
	else if (cmd === "reject") {
		byId(args[0]);
		notes.dropQueued(args[0]);
		console.log("rejected");
	} else if (cmd === "grants") {
		const g = notes.grants().files;
		if (json) console.log(JSON.stringify(g));
		else if (!g.length) console.log("No files are approved for agents to write without asking.");
		else for (const f of g) console.log(`${f.path}  (since ${f.since}, ${f.source ?? "?"})`);
	} else if (cmd === "grant") {
		if (!args[0]) throw new Error("usage: notes grant PATH (a folder ends in /)");
		notes.grant(args[0], "notes grant");
		console.log(notes.granted(args[0].endsWith("/") ? `${args[0].replace(/^\/+/, "")}x.md` : args[0]) ? `granted ${args[0]}` : `${args[0]} can't be granted`);
	} else if (cmd === "revoke") console.log(notes.revoke(args[0]) ? `revoked ${args[0]}` : `${args[0]} wasn't approved`);
	else if (cmd === "review") {
		const queued = notes.outbox();
		if (!queued.length) console.log("The outbox is empty.");
		const rl = createInterface({ input: process.stdin, output: process.stdout });
		for (const q of queued) {
			const { plan, error } = fresh(q);
			console.log(`\n=== ${q.path} (${q.mode}) from ${q.source ?? "an agent"}, ${q.created}`);
			if (error) {
				console.log(`  can't apply: ${error}`);
				const a = (await rl.question("[r]eject, [s]kip? ")).trim();
				if (a === "r") notes.dropQueued(q.id);
				continue;
			}
			console.log(plan.diff || "(no change)");
			const a = (await rl.question("[a]pply, [A]lways allow this file, [r]eject, [s]kip, [q]uit? ")).trim();
			if (a === "q") break;
			if (a === "a" || a === "A") console.log(`  wrote ${applyQueued(q, a === "A")}`);
			else if (a === "r") notes.dropQueued(q.id);
		}
		rl.close();
	} else {
		console.log(
			"usage: notes review | outbox [--json] | apply ID [--always] | reject ID | grant PATH | grants [--json] | revoke PATH | path",
		);
		process.exit(cmd ? 2 : 0);
	}
} catch (e) {
	console.error(`notes: ${e.message}`);
	process.exit(1);
}
