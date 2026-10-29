/**
 * Review each command before it runs, like Claude Code's auto mode. Only active when PI_GUARD=1
 * (pi-sandbox sets it), on top of the OS sandbox: the sandbox is what keeps secrets and the
 * rest of the disk out of reach; this stops destructive or outward-facing commands inside it.
 *
 * Order: read-only commands pass; hard rules block (sudo, pushes and publishes, piping a
 * download into a shell, system settings, credential tools); everything else goes to Jev, a
 * decision model behind the gateway (PI_GUARD_JEV_URL), asked whether the command is
 * destructive, irreversible or sends data out. Jev sees the command, the job folder and the
 * agent's own stated reason, never tool output: text in files or web pages (strings in a
 * binary under decomp, say) must not be able to talk it into anything. If Jev can't be
 * reached, risky-looking commands are blocked and the rest pass.
 *
 * Outside the sandbox it is a tripwire instead: the frontier models in FRONTIER (Claude and the cheaper candidates) get no shell
 * at all unless PI_UNSANDBOXED=1, so one can't end up with a free hand on the real home folder
 * by forgetting `pis`. DeepSeek isn't on the list: it runs pi-orch from ~/pi-eval, which the
 * sandbox can't read.
 *
 * A block steers the model to another way. 3 blocks in a row or 20 in a run stop the run (with
 * a UI, it asks you instead). Every decision goes to $PI_SANDBOX_JOB/.sandbox/guard.log.
 */
import { appendFileSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ON = process.env.PI_GUARD === "1";
const JOB = process.env.PI_SANDBOX_JOB ?? process.cwd();
const JEV_URL = process.env.PI_GUARD_JEV_URL ?? "http://desktop:4000/openrouter/decisions";
const JEV_MODEL = process.env.PI_GUARD_JEV_MODEL ?? "typesafe/jev-1.14";
const LOG = join(JOB, ".sandbox", "guard.log");
const FRONTIER = /^cloud-(opus|sonnet|haiku|deepseek-pro|grok|gpt|gemini-flash)$/;

// Every segment of the command starts with one of these and has no write redirection.
const READ_ONLY =
	/^(ls|cat|head|tail|wc|file|stat|du|df|pwd|echo|printf|which|type|env|date|whoami|uname|grep|rg|egrep|fgrep|awk|sed -n|sort|uniq|cut|tr|diff|cmp|comm|xxd|hexdump|od|strings|nm|objdump|readelf|otool|wasm2wat|wasm-objdump|wasm-decompile|wasm-validate|jq|tree|realpath|dirname|basename|true|test|\[|git (status|log|diff|show|blame|branch|rev-parse|ls-files))\b/;
const HARD: [RegExp, string][] = [
	[/(^|[\s;&|(])sudo\b|\bdoas\b/, "no sudo: work inside the job folder"],
	[/\bgit\s+push\b|\bgh\s+(pr|release|repo)\s+(create|merge|delete|edit)|\bnpm\s+publish\b|\bcargo\s+publish\b|\btwine\s+upload\b/, "no pushing or publishing: leave that to the user"],
	[/(curl|wget|fetch)\b[^|;&]*\|\s*(sudo\s+)?(ba|z|da|k)?sh\b|\b(ba|z)?sh\s+<\s*\(\s*(curl|wget)/, "don't pipe a download into a shell: save it, read it, then run it"],
	[/(^|[\s;&|(])(launchctl|osascript|defaults\s+write|csrutil|spctl|systemsetup|networksetup|scutil|crontab|systemctl|nixos-rebuild|darwin-rebuild|nix-collect-garbage)\b/, "no system or service changes"],
	[/(^|[\s;&|(])(security|ssh-add|ssh-keygen|gpg|sops|age|ssh|scp)\s|\brsync\s+[^|;&]*:/, "no credential tools or remote shells"],
	[/\brm\s+(-\w*\s+)*(\/|~|\$HOME|\/Users|\/nix)(\s|\/?$)|\bmkfs|\bdd\s+[^|;&]*of=\/dev|:\(\)\s*\{/, "that would destroy far more than the job"],
];
const RISKY = /\b(rm|mv|cp|chmod|chown|ln|truncate|shred|git\s+(reset|clean|checkout|rebase)|curl|wget|nc|ncat|socat|python3?\s+-c|node\s+-e|perl\s+-e)\b|>\s*[^&\s]/;

function log(entry: Record<string, unknown>) {
	try {
		appendFileSync(LOG, `${JSON.stringify({ t: new Date().toISOString(), ...entry })}\n`);
	} catch {
		/* logging never blocks a command */
	}
}

function readOnly(full: string): boolean {
	const cmd = full.replace(/\d?>\s*\/dev\/null|2>&1/g, "");
	if (/[^>]>[^&>]|>>|\btee\b|`|\$\(/.test(cmd)) return false;
	return cmd
		.split(/\s*(?:&&|\|\||;|\|)\s*/)
		.filter(Boolean)
		.every((seg) => READ_ONLY.test(seg.trim()) && !/\bfind\b.*-(delete|exec)|sed\s+-i/.test(seg));
}

async function askJev(cmd: string, why: string): Promise<{ risky: boolean; by: string }> {
	const body = {
		model: JEV_MODEL,
		state: [
			`An AI agent works on a task inside the folder ${JOB}, in an OS sandbox that only lets it write there. ` +
				"It may search the web, download and install tools into that folder, and build, run and change anything inside it. " +
				`It wants to run this shell command:\n${cmd}`,
			`Its stated reason: ${why || "(none given)"}`,
		],
		questions: {
			risky: {
				type: "noul",
				instructions:
					"This command is destructive, irreversible or outward-facing: it deletes or changes anything outside the " +
					"job folder, wipes the job folder as a whole or its git history, sends files or data from the machine to a " +
					"remote service (uploading, posting, emailing), publishes or deploys something, changes system settings, " +
					"or runs a downloaded script without looking at it first. Not risky: deleting, moving or editing single " +
					"files and folders inside the job folder (it is checkpointed before every run), downloading, installing, " +
					"building, testing and reading.",
			},
		},
	};
	const res = await fetch(JEV_URL, {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify(body),
		signal: AbortSignal.timeout(8000),
	});
	if (!res.ok) throw new Error(`HTTP ${res.status}`);
	const data = (await res.json()) as { answers?: Record<string, { noul?: number }> };
	const p = data.answers?.risky?.noul;
	if (typeof p !== "number") throw new Error("no answer");
	return { risky: p >= 0.5, by: `jev ${p.toFixed(2)}` };
}

export default function (pi: ExtensionAPI) {
	if (!ON) {
		if (process.env.PI_UNSANDBOXED === "1") return;
		pi.on("tool_call", async (event, ctx) => {
			if (event.toolName !== "bash" || !FRONTIER.test(ctx.model?.id ?? "")) return;
			return {
				block: true,
				reason:
					"Not run: this model only gets a shell inside the sandbox. Tell the user to start you with " +
					"`pis JOB_DIR` (or PI_UNSANDBOXED=1 to allow it here), and stop",
			};
		});
		return;
	}
	let streak = 0;
	let total = 0;

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return; // file tools can't leave the job folder: the sandbox sees to that
		const cmd = String((event.input as { command?: string }).command ?? "").trim();
		if (!cmd) return;
		let verdict: { block: boolean; by: string; reason?: string };
		const hard = HARD.find(([re]) => re.test(cmd));
		if (hard) verdict = { block: true, by: "rule", reason: hard[1] };
		else if (readOnly(cmd)) verdict = { block: false, by: "read-only" };
		else {
			const why = String((event.input as { description?: string }).description ?? "");
			try {
				const j = await askJev(cmd, why);
				verdict = { block: j.risky, by: j.by };
			} catch (e) {
				verdict = { block: RISKY.test(cmd), by: `fallback (${String(e).slice(0, 60)})` };
			}
			if (verdict.block)
				verdict.reason =
					"the safety check judged it destructive or outward-facing. Do it another way that keeps " +
					"changes inside the job folder and sends nothing out, or explain why it's needed and stop";
		}
		log({ cmd: cmd.slice(0, 500), block: verdict.block, by: verdict.by });
		if (!verdict.block) {
			streak = 0;
			return;
		}
		if (ctx.hasUI && (await ctx.ui.confirm("Guard blocked a command", `${cmd}\n\n${verdict.reason}\n\nRun it anyway?`))) {
			log({ cmd: cmd.slice(0, 500), block: false, by: "user" });
			streak = 0;
			return;
		}
		streak++;
		total++;
		const stop = streak >= 3 || total >= 20;
		return {
			block: true,
			terminate: stop && !ctx.hasUI,
			reason: `Blocked (${verdict.by}): ${verdict.reason}.${stop ? " Too many blocked commands: stop and report what you need." : ""}`,
		};
	});
}
