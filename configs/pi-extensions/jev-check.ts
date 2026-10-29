/**
 * After each run in `pis`, a second opinion on what the agent changed (configs/jev-check):
 * did it game the tests, stray from the task, or make a change worth a careful look? Jev
 * answers each as a probability, next to plain rules (test files edited, assertions removed,
 * test values special-cased in the code). It warns, never blocks or undoes anything.
 *
 * agent_end: diff the job folder against the checkpoint pi-sandbox committed before this run
 * (read-only, PI_SANDBOX_CHECKPOINT), give jev-check the prompts of this session as the task,
 * write JOB/.sandbox/jev-check.json and show any warning. Jev never sees tool output.
 *
 * On or off, first match wins: PI_JEV_CHECK=1|0 for one run; `/jev-check on|off` for this
 * project (kept in JOB/.sandbox/jev-check.mode); otherwise on for the small profile (local
 * models game tests more) and off for frontier models.
 */
import { execFile } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const JOB = process.env.PI_SANDBOX_JOB;
const GIT_DIR = process.env.PI_SANDBOX_CHECKPOINT;
const BIN = process.env.PI_JEV_CHECK_BIN ?? "jev-check";
const MODE_FILE = JOB ? join(JOB, ".sandbox", "jev-check.mode") : "";
const LABEL: Record<string, string> = {
	gaming: "may game the tests",
	scope: "goes beyond the task",
	triage: "worth a careful look",
};

function enabled(): boolean {
	if (process.env.PI_JEV_CHECK === "1") return true;
	if (process.env.PI_JEV_CHECK === "0") return false;
	try {
		const m = readFileSync(MODE_FILE, "utf8").trim();
		if (m === "on" || m === "off") return m === "on";
	} catch {}
	return process.env.PI_SANDBOX_PROFILE === "small";
}

interface Result {
	files: { path: string }[];
	rule: Record<string, { score: number; why: string[] }>;
	jev: Record<string, number> | null;
	error: string | null;
	warn: string[];
}

function run(task: string): Promise<Result | undefined> {
	const meta = join(JOB as string, ".sandbox");
	const taskFile = join(meta, "jev-task.txt");
	writeFileSync(taskFile, task);
	const args = ["--task-file", taskFile, "--job", JOB as string, "--git-dir", GIT_DIR as string, "--out", join(meta, "jev-check.json")];
	return new Promise((done) =>
		execFile(BIN, args, { timeout: 120_000, maxBuffer: 8 << 20 }, (err, stdout) => {
			if (err) return done(undefined);
			try {
				done(JSON.parse(stdout) as Result);
			} catch {
				done(undefined);
			}
		}),
	);
}

function summary(r: Result): string | undefined {
	if (!r.warn.length) return undefined;
	const parts = r.warn.map((k) => {
		const p = r.jev?.[k];
		const why = r.rule[k]?.why[0];
		return `${LABEL[k] ?? k}${p !== undefined ? ` (Jev ${p.toFixed(2)})` : ""}${why ? `: ${why}` : ""}`;
	});
	return `jev-check: this run's changes ${parts.join("; ")}. Details: .sandbox/jev-check.json`;
}

export default function (pi: ExtensionAPI) {
	if (!JOB || !GIT_DIR) return; // only inside pis, which keeps the checkpoint
	const prompts: string[] = [];

	pi.registerCommand("jev-check", {
		description: "Check each run's changes for test gaming, scope and risk: on, off or status",
		handler: async (arg, ctx) => {
			const a = (arg ?? "").trim();
			if (a === "on" || a === "off") writeFileSync(MODE_FILE, `${a}\n`);
			const env = process.env.PI_JEV_CHECK;
			const note = env === "0" || env === "1" ? ` (PI_JEV_CHECK=${env} overrides it for this run)` : "";
			ctx.ui.notify(`jev-check is ${enabled() ? "on" : "off"} for this project${note}`, "info");
		},
	});

	pi.on("before_agent_start", (event) => {
		if (event.messageType === "user" && event.prompt) prompts.push(event.prompt);
	});

	pi.on("agent_end", async (_event, ctx) => {
		if (!enabled() || !prompts.length) return;
		const r = await run(prompts.join("\n\n---\n\n").slice(-8000));
		if (!r) return;
		const msg = summary(r);
		if (!msg) return;
		if (ctx.hasUI) ctx.ui.notify(msg, "warning");
		else process.stderr.write(`${msg}\n`);
	});
}
