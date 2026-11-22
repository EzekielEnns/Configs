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
 * - Network: any public host, each one logged to JOB_DIR/.sandbox/net.log. srt refuses loopback,
 *   link-local and cloud-metadata targets; private, Tailscale (CGNAT) and ULA addresses are
 *   refused here too, by name or literal, except the gateway host's own service ports
 *   (GATEWAY_PORTS: the model gateway and the evidence service). So an agent can't reach ssh,
 *   Rex's server or anything else on the desktop or the LAN. Agents can look things up and
 *   download tools; what they can send out is what's in JOB_DIR, since the rest of the
 *   secrets can't be read.
 * - Environment: built from scratch, nothing inherited from the shell but what's listed.
 *   HOME stays real (Pi reads its config there); npm, pip, cargo and go install into
 *   JOB_DIR/.tools, whose bin is first on PATH.
 * - Pi gets its own agent folder, JOB_DIR/.sandbox/pi-agent: links to ~/.pi/agent's extensions,
 *   prompts, agents and models (the gateway's key is in models.json), a copy of settings, and
 *   its sessions there. Not auth.json (other providers' keys).
 * - Memory: ~/.pi/memory's shared facts read-only, and the job's own project memory.
 * PI_GUARD=1 turns on guard.ts, the per-command classifier, inside the sandbox.
 * PI_JEV_CHECK=1|0 forces jev-check.ts (a second opinion on each run's changes) on or off.
 * - Notes (configs/notes): the vault is read-only in here. An approved notes_write reaches this
 *   launcher as a request signed with a key handed to Pi on an inherited pipe (fd 3); the
 *   launcher checks the signature and the vault's rules, writes the note, and keeps "always"
 *   grants. Writes nobody approved go to the outbox when the run ends.
 */
import { spawn, spawnSync } from "node:child_process";
import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import {
	appendFileSync, existsSync, mkdirSync, readdirSync, readFileSync, realpathSync, rmSync, statSync, symlinkSync,
	writeFileSync,
} from "node:fs";
import { lookup } from "node:dns/promises";
import { isIP } from "node:net";
import { homedir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";

const { SandboxManager } = await import(process.env.PI_SANDBOX_SRT ?? "@SRT@");
const notes = process.env.PI_SANDBOX_NOTES_CORE ? await import(process.env.PI_SANDBOX_NOTES_CORE) : null;

const HOME = homedir();
const GATEWAY = (process.env.PI_SANDBOX_GATEWAY ?? "desktop").split(",");
// The gateway host's services the tools use: 4000 the LiteLLM gateway (models, Jev), 8090 the
// evidence service. Nothing else on that host: not ssh, not Rex's server (7297).
const GATEWAY_PORTS = (process.env.PI_SANDBOX_GATEWAY_PORTS ?? "4000,8090").split(",");
// Private-use, Tailscale (100.64/10) and ULA space: names that resolve here, and literals, are
// refused unless allowed above. srt leaves these open by default (allow-listing an intranet
// name is legitimate), and the desktop and the LAN live here.
const PRIVATE = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10", "fc00::/7"];
const inV4 = (ip, cidr) => {
	const [net, bits] = cidr.split("/");
	const n = (a) => a.split(".").reduce((x, o) => x * 256 + Number(o), 0);
	const size = 2 ** (32 - Number(bits));
	return Math.floor(n(ip) / size) === Math.floor(n(net) / size);
};
const isPrivate = (ip) => {
	const v4 = ip.startsWith("::ffff:") ? ip.slice(7) : ip;
	if (isIP(v4) === 4) return PRIVATE.slice(0, 4).some((c) => inV4(v4, c));
	return /^f[cd]/i.test(ip);
};
// The gateway's addresses (srt allows a name into private space only when that address is
// allowed as a literal on the same port).
const gatewayIps = (await Promise.all(GATEWAY.map((h) => lookup(h, { all: true }).catch(() => []))))
	.flat().map((a) => a.address);
const ALLOWED = [...GATEWAY, ...gatewayIps].flatMap((h) => GATEWAY_PORTS.map((p) => `${h.includes(":") ? `[${h}]` : h}:${p}`));
const DENY_READ = [
	"~/.ssh", "~/.gnupg", "~/.aws", "~/.azure", "~/.config/gcloud", "~/.kube", "~/.docker",
	"~/.netrc", "~/.npmrc", "~/.pypirc", "~/.git-credentials", "~/.config/gh", "~/.config/sops",
	// The board's token (it opens the desktop's board node) and its database copies.
	"~/.board/token", "~/.board/board.db", "~/.board/replica.db",
	"~/.config/age", "~/.age", "~/.pi/auth.json", "~/.pi/memory/projects", "~/.srt-settings.json",
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
// The grep and find tools (ripgrep, fd) skip what an .ignore file lists, so searches don't
// turn up Pi's own session logs or installed tools.
for (const d of [meta, tools, join(job, ".tmp")]) writeFileSync(join(d, ".ignore"), "*\n");

// Pi's own agent folder: Pi writes lock files and sessions next to its config.
const piHome = join(HOME, ".pi/agent");
const agentDir = join(meta, "pi-agent");
mkdirSync(join(agentDir, "sessions"), { recursive: true });
const small = process.env.PI_SANDBOX_PROFILE === "small";
const links = {
	agents: "agents", bin: "bin", extensions: "extensions", "models.json": "models.json", prompts: "prompts",
	// Frontier models skip the local models' 16k-output rules (write in 150-line parts).
	"APPEND_SYSTEM.md": small ? "APPEND_SYSTEM.md" : "system-frontier.md",
};
for (const [name, target] of Object.entries(links)) {
	const link = join(agentDir, name);
	// rm, not unlink: the agent could have swapped a link for a folder of its own.
	rmSync(link, { recursive: true, force: true });
	if (existsSync(join(piHome, target))) symlinkSync(join(piHome, target), link);
}
// MCP servers start with Pi, possibly before notes.ts has taken the broker key: none from here.
rmSync(join(agentDir, "mcp.json"), { force: true });
// Settings: the global ones, refreshed every run so config changes reach old jobs, plus this
// job's model: a pick made with /model or Ctrl+P is remembered here. Frontier runs start on
// the cheapest hosted model (PI_SANDBOX_MODEL to change it) instead of the global Flint.
const settingsFile = join(agentDir, "settings.json");
const readJson = (f) => { try { return JSON.parse(readFileSync(f, "utf8")); } catch { return {}; } };
const saved = readJson(settingsFile);
const settings = { ...readJson(join(piHome, "settings.json")) };
if (saved.defaultModel && !(saved.defaultModel === "flint" && !small)) {
	settings.defaultProvider = saved.defaultProvider ?? "desktop";
	settings.defaultModel = saved.defaultModel;
} else if (!small) {
	settings.defaultProvider = "desktop";
	settings.defaultModel = process.env.PI_SANDBOX_MODEL ?? "cloud-deepseek";
}
// Frontier models also get Pi's ripgrep-backed grep and find tools: they skip .gitignore'd
// files and cap output, so one search can't flood the context. Small models stay lean.
if (!small) settings.defaultTools = [...(settings.defaultTools ?? []), "+grep", "+find"];
writeFileSync(settingsFile, `${JSON.stringify(settings, null, 2)}\n`);

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

// Memory (pi-extensions/memory.ts): the facts for every project, read-only, and this job's
// own folder, read-write; other projects' memories stay unreadable. Same key as memory.ts.
const projectKey = (dir) => {
	const rel = dir.startsWith(HOME) ? dir.slice(HOME.length) : dir;
	const s = rel.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
	return s.length <= 60 ? s : `${s.slice(-50)}-${createHash("sha256").update(dir).digest("hex").slice(0, 8)}`;
};
const memory = join(HOME, ".pi/memory/projects", projectKey(job));
mkdirSync(memory, { recursive: true });

const netLog = join(meta, "net.log");
const config = {
	allowPty: true, // macOS: Pi's interactive screen needs raw mode on its terminal
	network: {
		allowedDomains: ALLOWED,
		deniedDomains: ["*:7297"],
		deniedDomainReasons: {
			"*:7297": "Rex's server is off limits: it would be a shell outside the sandbox. Ask the user to run it.",
		},
		deniedResolvedAddresses: PRIVATE,
		// The s-chan board: post and read through this machine's node (board.sock), and
		// listen in ~/.board/pi so the node can wake this session. Trusted like any local
		// agent: whoever reaches board.sock can post under any name. macOS only; srt
		// ignores the path list on Linux.
		allowUnixSockets: [join(HOME, ".board")],
	},
	filesystem: {
		denyRead: DENY_READ.map((p) => p.replace(/^~/, HOME)),
		// The checkpoint repo read-only: jev-check.ts diffs the job against it.
		allowRead: [job, memory, checkpoints],
		allowWrite: [job, memory, join(HOME, ".board/pi"), join(HOME, ".board/hook.log")],
		// The notes vault and its grants: read-only even for a job folder inside them.
		denyWrite: notes ? [notes.VAULT, notes.STATE] : [],
	},
};
// Hosts not on the list: allowed and logged (srt has already refused private addresses).
const ask = async ({ host, port }) => {
	// A private address typed as a literal: refused here (the resolved-address check covers names).
	const ok = !(isIP(host.replace(/^\[|\]$/g, "")) && isPrivate(host.replace(/^\[|\]$/g, "")));
	appendFileSync(netLog, `${new Date().toISOString()} ${host}:${port}${ok ? "" : " refused"}\n`);
	return ok;
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
	// would cut a frontier brain's reads, and 150-line writes suit a 16k output cap, not 64k.
	// PI_SANDBOX_PROFILE=small keeps them.
	...(small
		? {}
		: { PI_MASK: "0", PI_THINKING: "0", PI_BUDGET_TURN: "0", PI_DELEGATE: "0", PI_READ_LIMIT: "800", PI_WRITE_MAX_LINES: "800" }),
	// The sandbox blocks macOS's pasteboard service, so Pi's copy also goes out through the
	// terminal (OSC 52), as it does over SSH.
	PI_CLIPBOARD_OSC52: "1",
	// Rex's IDs (not its control socket): Pi detects Rex for clickable links, and links.ts
	// writes nvim-open:// links that open in this tab (configs/nvim-open).
	...Object.fromEntries(["TERM_PROGRAM", "REX_SESSION", "REX_BLOCK"].filter((k) => process.env[k]).map((k) => [k, process.env[k]])),
	PI_CODING_AGENT_DIR: agentDir,
	PI_SANDBOX_JOB: job,
	PI_SANDBOX_CHECKPOINT: checkpoints,
	PI_SANDBOX_PROFILE: small ? "small" : "frontier",
	...(process.env.PI_JEV_CHECK ? { PI_JEV_CHECK: process.env.PI_JEV_CHECK } : {}),
	...(process.env.PI_POI ? { PI_POI: process.env.PI_POI } : {}),
	...(process.env.PI_JEV_CHECK_BIN ? { PI_JEV_CHECK_BIN: process.env.PI_JEV_CHECK_BIN } : {}),
	// Where the notes vault and its state live, if not ~/Notes (configs/notes/core.mjs).
	...Object.fromEntries(["NOTES_DIR", "NOTES_STATE", "NOTES_PROTECTED"].filter((k) => process.env[k]).map((k) => [k, process.env[k]])),
	PI_GUARD: process.env.PI_GUARD ?? "1",
	...(process.env.PI_GUARD_JEV_URL ? { PI_GUARD_JEV_URL: process.env.PI_GUARD_JEV_URL } : {}),
};

const quote = (a) => (/^[\w@%+=:,./-]+$/.test(a) ? a : `'${a.replace(/'/g, `'\\''`)}'`);
const argv = rest.length ? rest : ["pi"];
const command = argv.map(quote).join(" ");

// Notes broker: only for Pi with its extensions on, where notes.ts reads the key at load and
// closes the pipe before any tool runs. Any other command would hand the key to whatever runs.
const brokerDir = join(meta, "notes-broker");
const outboxDir = join(meta, "notes-outbox");
const brokerKey =
	notes && basename(argv[0]) === "pi" && !argv.some((a) => /^(-ne|--no-extensions?|-nt|--no-tools)$/.test(a))
		? randomBytes(32)
		: null;
const seen = new Set();
let hello = false;
let broken = false;
function serve() {
	if (!existsSync(brokerDir)) return;
	for (const f of readdirSync(brokerDir).filter((n) => /^req-[\w.-]+\.json$/.test(n))) {
		const file = join(brokerDir, f);
		let res = { ok: false, error: "bad request" };
		let nonce = null;
		try {
			if (statSync(file).size > 2_000_000) throw new Error("too big");
			const { body, sig } = JSON.parse(readFileSync(file, "utf8"));
			const want = createHmac("sha256", brokerKey).update(String(body)).digest();
			const got = Buffer.from(String(sig), "hex");
			if (got.length !== want.length || !timingSafeEqual(got, want)) throw new Error("not signed by notes.ts");
			const req = JSON.parse(body);
			nonce = String(req.nonce ?? "");
			if (!/^[\w.-]{1,80}$/.test(nonce) || seen.has(nonce)) throw new Error("replayed");
			seen.add(nonce);
			if (req.hello) {
				// A second hello means someone else had the key: stop trusting it.
				if (hello) {
					broken = true;
					process.stderr.write("pi-sandbox: notes key seen twice; notes writes are off for this run\n");
				}
				hello = true;
				res = { ok: true };
			} else if (broken || !hello) throw new Error("notes writes are off for this run");
			else {
				const plan = notes.plan({ path: req.path, mode: req.mode, text: req.text, old: req.old ?? undefined });
				// The exact change the user saw: same file contents as when it was shown.
				if (plan.beforeHash !== req.beforeHash) throw new Error("the note changed since you saw the diff");
				const written = notes.apply(plan);
				if (req.always) notes.grant(written, String(req.source ?? `pis ${job}`));
				appendFileSync(join(meta, "notes.log"), `${new Date().toISOString()} wrote ${written}${req.always ? " (always)" : ""}\n`);
				res = { ok: true, path: written };
			}
		} catch (e) {
			res = { ok: false, error: e.message };
		}
		rmSync(file, { force: true });
		if (nonce && /^[\w.-]{1,80}$/.test(nonce)) writeFileSync(join(brokerDir, `res-${nonce}.json`), JSON.stringify(res));
	}
}
// Writes nobody approved (no UI): into the real outbox, which the sandbox can't write.
function drainOutbox() {
	if (!notes || !existsSync(outboxDir)) return;
	for (const f of readdirSync(outboxDir).filter((n) => n.endsWith(".json")).slice(0, 50)) {
		const file = join(outboxDir, f);
		try {
			if (statSync(file).size <= 2_000_000) {
				const r = JSON.parse(readFileSync(file, "utf8"));
				let diff = "";
				try { diff = notes.plan({ path: r.path, mode: r.mode, text: r.text, old: r.old ?? undefined }).diff; } catch (e) { diff = `(${e.message})`; }
				notes.queue({ path: String(r.path), mode: String(r.mode), text: String(r.text), old: r.old ?? null, source: `pis ${job}`, diff });
			}
		} catch {}
		rmSync(file, { force: true });
	}
}

rmSync(brokerDir, { recursive: true, force: true });
await SandboxManager.initialize(config, ask);
const wrapped = await SandboxManager.wrapWithSandbox(command);
const child = spawn(wrapped, {
	shell: true,
	stdio: brokerKey ? ["inherit", "inherit", "inherit", "pipe"] : "inherit",
	cwd: job,
	// --disable-sigusr1: the agent can't open Node's inspector on Pi (and read the key from it).
	env: brokerKey ? { ...env, NOTES_KEY_FD: "3", NODE_OPTIONS: "--disable-sigusr1" } : env,
});
let timer = null;
if (brokerKey) {
	child.stdio[3].on("error", () => {});
	child.stdio[3].end(brokerKey.toString("hex"));
	timer = setInterval(serve, 200);
}
const stop = (sig) => child.kill(sig);
process.on("SIGINT", stop);
process.on("SIGTERM", stop);
child.on("exit", async (code, signal) => {
	if (timer) {
		clearInterval(timer);
		serve();
	}
	drainOutbox();
	await SandboxManager.reset();
	process.exit(code ?? (signal ? 1 : 0));
});
