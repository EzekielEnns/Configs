#!/usr/bin/env node
/**
 * pi-sandbox: run Pi (or any command) in a job folder under Anthropic's sandbox runtime.
 *
 *   pi-sandbox JOB_DIR [-- COMMAND ...]     default command: pi
 *
 * The whole process tree is sandboxed (Seatbelt on macOS, bubblewrap on Linux), not just
 * Pi's shell tool: a sandbox around part of the tree is escaped by any child it spawns.
 * - Writes: only JOB_DIR. Before each run its files are committed to a checkpoint repo
 *   outside it (<parent>/.checkpoints/<name>.git), which the agent can't write: in a test it
 *   ran `rm -rf .git` in the job. Roll back with
 *   git --git-dir=<parent>/.checkpoints/<name>.git --work-tree=JOB_DIR checkout -f HEAD -- .
 * - Reads: everything except the secret and personal paths in DENY_READ (keys, tokens,
 *   keychains, shell history, browser and mail data, ~/Documents with all the repos).
 * - Network: any public host, each one logged to JOB_DIR/.sandbox/net.log. srt itself refuses
 *   loopback, link-local, cloud-metadata and other private targets; only the gateway is let
 *   through by name. Agents can look things up and download tools; what they can send out
 *   is what's in JOB_DIR, since the rest of the secrets can't be read.
 * - Environment: built from scratch, nothing inherited from the shell but what's listed.
 *   HOME stays real (Pi reads its config there); npm, pip, cargo and go install into
 *   JOB_DIR/.tools, whose bin is first on PATH.
 * - Pi gets its own agent folder, JOB_DIR/.sandbox/pi-agent: links to ~/.pi/agent's extensions,
 *   prompts, agents and models (the gateway's key is in models.json), a copy of settings, and
 *   its sessions there. Not auth.json (other providers' keys) or ~/.pi/memory.
 * PI_GUARD=1 turns on guard.ts, the per-command classifier, inside the sandbox.
 */
import { spawn, spawnSync } from "node:child_process";
import { appendFileSync, copyFileSync, existsSync, mkdirSync, realpathSync, symlinkSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";

const { SandboxManager } = await import(process.env.PI_SANDBOX_SRT ?? "@SRT@");

const HOME = homedir();
const GATEWAY = (process.env.PI_SANDBOX_GATEWAY ?? "desktop").split(",");
const DENY_READ = [
	"~/.ssh", "~/.gnupg", "~/.aws", "~/.azure", "~/.config/gcloud", "~/.kube", "~/.docker",
	"~/.netrc", "~/.npmrc", "~/.pypirc", "~/.git-credentials", "~/.config/gh", "~/.config/sops",
	"~/.config/age", "~/.age", "~/.pi/auth.json", "~/.pi/memory", "~/.srt-settings.json",
	"~/.zsh_history", "~/.bash_history", "~/.local/share/fish", "~/.histfile",
	"~/Library/Keychains", "~/Library/Cookies", "~/Library/Mail", "~/Library/Messages",
	"~/Library/Safari", "~/Library/Application Support", "~/Library/Containers",
	"~/Library/Group Containers", "~/Library/Accounts", "~/Library/Calendars",
	"~/Documents", "~/Desktop", "~/Downloads", "~/Pictures", "~/Movies", "~/Music",
	"~/.claude", "~/.config/rex", "~/pi-eval",
	"/var/lib/ai-stack", "/etc/ssh", "/run/secrets",
];

const [jobArg, sep, ...rest] = process.argv.slice(2);
if (!jobArg || (sep !== undefined && sep !== "--")) {
	console.error("usage: pi-sandbox JOB_DIR [-- COMMAND ...]");
	process.exit(2);
}
mkdirSync(jobArg, { recursive: true });
const job = realpathSync(resolve(jobArg));
if (job === HOME || HOME.startsWith(`${job}/`)) {
	console.error("pi-sandbox: the job folder can't be your home folder or above it");
	process.exit(2);
}
const meta = join(job, ".sandbox");
const tools = join(job, ".tools");
for (const d of [meta, tools, join(job, ".tmp"), join(tools, "bin")]) mkdirSync(d, { recursive: true });

// Pi's own agent folder: Pi writes lock files and sessions next to its config.
const piHome = join(HOME, ".pi/agent");
const agentDir = join(meta, "pi-agent");
mkdirSync(join(agentDir, "sessions"), { recursive: true });
for (const name of ["agents", "APPEND_SYSTEM.md", "bin", "extensions", "models.json", "prompts"]) {
	const link = join(agentDir, name);
	if (existsSync(join(piHome, name)) && !existsSync(link)) symlinkSync(join(piHome, name), link);
}
if (existsSync(join(piHome, "settings.json")) && !existsSync(join(agentDir, "settings.json")))
	copyFileSync(join(piHome, "settings.json"), join(agentDir, "settings.json"));

// Checkpoint: the job's files, committed to a repo outside the job before every run.
const checkpoints = join(dirname(job), ".checkpoints", `${basename(job)}.git`);
const git = (...args) =>
	spawnSync("git", [`--git-dir=${checkpoints}`, `--work-tree=${job}`, ...args], { encoding: "utf8" });
if (!existsSync(checkpoints)) {
	mkdirSync(checkpoints, { recursive: true });
	spawnSync("git", ["init", "-q", "--bare", checkpoints]);
	writeFileSync(join(checkpoints, "info", "exclude"), ".tools/\n.tmp/\n.sandbox/\n.git/\n");
}
git("add", "-A");
git("-c", "user.name=pi-sandbox", "-c", "user.email=pi-sandbox@localhost", "commit", "-q", "--allow-empty", "-m",
	`checkpoint before run ${new Date().toISOString()}`);

const netLog = join(meta, "net.log");
const config = {
	network: { allowedDomains: GATEWAY, deniedDomains: [] },
	filesystem: {
		denyRead: DENY_READ.map((p) => p.replace(/^~/, HOME)),
		allowRead: [job],
		allowWrite: [job],
		denyWrite: [],
	},
};
// Hosts not on the list: allowed and logged (srt has already refused private addresses).
const ask = async ({ host, port }) => {
	appendFileSync(netLog, `${new Date().toISOString()} ${host}:${port}\n`);
	return true;
};

const env = {
	HOME,
	USER: process.env.USER ?? "",
	LANG: process.env.LANG ?? "en_US.UTF-8",
	TERM: process.env.TERM ?? "xterm-256color",
	SHELL: "/bin/sh",
	PATH: [join(tools, "bin"), join(tools, "node/bin"), join(tools, "go/bin"), join(tools, "cargo/bin"), process.env.PATH].join(":"),
	TMPDIR: join(job, ".tmp"),
	npm_config_prefix: join(tools, "node"),
	npm_config_cache: join(tools, "npm-cache"),
	PIP_CACHE_DIR: join(tools, "pip-cache"),
	PYTHONUSERBASE: join(tools, "python"),
	CARGO_HOME: join(tools, "cargo"),
	GOPATH: join(tools, "go"),
	GOCACHE: join(tools, "go-cache"),
	XDG_CACHE_HOME: join(tools, "cache"),
	// Frontier profile: these helpers trim history for 32k local slots, but rewriting old
	// messages breaks a hosted model's prompt cache on every turn, and the delegate budget
	// would cut a frontier brain's reads. PI_SANDBOX_PROFILE=small keeps them.
	...(process.env.PI_SANDBOX_PROFILE === "small"
		? {}
		: { PI_MASK: "0", PI_THINKING: "0", PI_BUDGET_TURN: "0", PI_DELEGATE: "0", PI_READ_LIMIT: "800" }),
	PI_CODING_AGENT_DIR: agentDir,
	PI_MEMORY: "0", // ~/.pi/memory is unreadable in here, and a job shouldn't write to it
	PI_SANDBOX_JOB: job,
	PI_GUARD: process.env.PI_GUARD ?? "1",
	...(process.env.PI_GUARD_JEV_URL ? { PI_GUARD_JEV_URL: process.env.PI_GUARD_JEV_URL } : {}),
};

const quote = (a) => (/^[\w@%+=:,./-]+$/.test(a) ? a : `'${a.replace(/'/g, `'\\''`)}'`);
const command = (rest.length ? rest : ["pi"]).map(quote).join(" ");

await SandboxManager.initialize(config, ask);
const wrapped = await SandboxManager.wrapWithSandbox(command);
const child = spawn(wrapped, { shell: true, stdio: "inherit", cwd: job, env });
const stop = (sig) => child.kill(sig);
process.on("SIGINT", stop);
process.on("SIGTERM", stop);
child.on("exit", async (code, signal) => {
	await SandboxManager.reset();
	process.exit(code ?? (signal ? 1 : 0));
});
