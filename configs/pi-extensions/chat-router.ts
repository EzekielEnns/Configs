/**
 * pichat's router: one model to pick, `desktop/pichat`, that sends each message to Bolt or
 * to the planner.
 *
 * - Chat (small talk, roleplay, opinions, images, notes): Bolt, with the notes tools.
 * - Lookups (anything factual or checkable): the planner (Qwen3.5 9B, 10/10 in the
 *   2026-11-01 bake-off, ai-stack docs/MODEL-WATCH.md) with lookup and dig, which hand it
 *   short checked passages that Bolt reads. Given web_search and fetch_content as well, the
 *   planner read raw pages and made up details, so lookups get only these two.
 *
 * Jev decides from the new message and the last reply (the one cloud call, allowed for
 * pichat; PICHAT_DECIDER=qwen keeps it local). If Jev fails, the planner decides, thinking off,
 * in one word. A message starting with "?" is always a lookup; one with an image always goes
 * to Bolt. Tool follow-ups stay on the model that started the turn. Every model is local.
 *
 * Speed (ai-stack docs/SPEED-COST-PLAN.md B and C):
 * - Once a message is answered, its lookup passages leave the context: the model sees a stub
 *   with the pages' titles and URLs. The speaker chat kept 23 lookups' passages and compacted
 *   3 times in 6 messages. PICHAT_PRUNE=0 keeps them.
 * - After each lookup Jev asks whether the passages so far answer the message; when they do,
 *   or after PICHAT_MAX_LOOKUPS (3), the result says to answer now and lookup and dig are
 *   switched off. It had searched up to 7 times a message. PICHAT_ENOUGH_AT sets Jev's cutoff (0 = off).
 *
 * Checks on a lookup answer, in code because prompt rules didn't hold: links not in this chat's
 * tool results are taken out, and prices and numbers with units that aren't are listed under it.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const GATEWAY = process.env.PI_READER_GATEWAY ?? "http://desktop:4000/v1";
const PROVIDER = "desktop";
const TALKER = "bolt";
const PLANNER = process.env.PICHAT_PLANNER ?? "planner-qwen9b";
const NOTES = ["notes_search", "notes_read", "notes_recent", "notes_write"];
const CHAT_TOOLS = NOTES;
const LOOK_TOOLS = ["lookup", "dig", ...NOTES];

const DECIDE = `You route messages in a chat app. Reply with one word.
LOOKUP: answering well needs anything from the web: links, products, parts lists, prices,
recommendations of things to buy or use, setups and how-tos, specs, news, releases, dates,
people, places, or details of books, shows, games and anime (plots, characters, who dies,
episode counts). Also LOOKUP when the user asks to look something up, search, or get links.
CHAT: only small talk, feelings, opinions, jokes, roleplay or story writing, or questions
answered entirely from the conversation itself. If unsure, LOOKUP.`;

const LOOK_GUIDE = `

LOOKUPS
- This message needs facts. First work out what the user is actually trying to do from the
  whole conversation (earlier replies may have misread it), then look up the pieces that
  solves. Call lookup with a precise question; use dig for questions with several parts or
  when lookup's passages don't settle it. Search again with sharper wording if the answer is
  missing.
- Answer only from the passages you got, in the same friendly tone. Every product, price,
  spec and link you give must appear in a passage, with that passage's URL beside it. If no
  passage gave a price or a link, say so instead of filling one in.
- Say plainly what you couldn't find instead of guessing.`;

type Mode = "chat" | "look";
type Block = { type?: string; text?: string };
type Msg = { role?: string; content?: unknown; toolName?: string };

const LOOKERS = new Set(["lookup", "dig"]);
const PRUNE = process.env.PICHAT_PRUNE !== "0";
const MAX_LOOKS = Number(process.env.PICHAT_MAX_LOOKUPS ?? 3);
const ENOUGH_AT = Number(process.env.PICHAT_ENOUGH_AT ?? 0.7);
const ENOUGH_Q =
	"The passages found so far contain what is needed to answer the user's message well: the specific facts, " +
	"products, prices, specs or links it asks for. Nothing important the message asks for is missing from them.";
const textOf = (content: unknown) =>
	Array.isArray(content) ? (content as Block[]).flatMap((b) => (b.type === "text" && b.text ? [b.text] : [])).join("\n") : "";

/** An answered message's lookup result, as the model sees it later: the pages, not the passages. */
function stub(m: Msg, text: string): Msg {
	const pages = [...text.matchAll(/^## (.+)\n(https?:\/\/\S+)/gm)].slice(0, 8).map((x) => `- ${x[1].slice(0, 100)}: ${x[2]}`);
	const note = `[Earlier ${m.toolName} result, answered above; its passages are hidden now. Look it up again if a new question needs them.${pages.length ? `\nPages:\n${pages.join("\n")}` : ""}]`;
	return { ...m, content: [{ type: "text", text: note }] };
}

// The planner, asked for links, fills in plausible ones (Amazon /dp/ pages it never saw). Links in
// a lookup answer must come from this run's tool results; the rest are taken out.
const URL_RE = /https?:\/\/[^\s<>"'`)\]]+/g;
const norm = (u: string) => u.replace(/[.,;:!?]+$/, "").replace(/\/+$/, "");

function stripUnseenLinks(text: string, seen: Set<string>): { text: string; removed: number } {
	const ok = (u: string) => {
		const n = norm(u);
		for (const s of seen) if (s === n || s.startsWith(n + "/") || s.startsWith(n + "?")) return true;
		return false;
	};
	let removed = 0;
	let out = text.replace(/\[([^\]]*)\]\((https?:\/\/[^)\s]+)\)/g, (m, label: string, url: string) => {
		if (ok(url)) return m;
		removed++;
		return label;
	});
	out = out.replace(URL_RE, (url) => {
		if (ok(url)) return url;
		removed++;
		return "(link removed)";
	});
	return { text: out, removed };
}

// Prices and numbers with units get the same check as links, but are listed under the answer
// rather than removed: some are totals the planner added up. In the 2026-11-02 speaker chat 25
// prices were in none of the pages found.
const NUM_RE =
	/[$€£]\s?\d[\d,]*(?:\.\d+)?|\b\d[\d,]*(?:\.\d+)?\s?(?:W|V|A|mAh|Wh|Hz|kHz|MHz|GHz|GB|MB|TB|mm|cm|kg|ohms?|Ω|%|fps|dB)\b/g;

function unseenNumbers(text: string, corpus: string): string[] {
	const out = new Set<string>();
	for (const m of text.matchAll(NUM_RE)) {
		const d = m[0].replace(/[^\d.]/g, "").replace(/\.0+$/, "").replace(/\.$/, "");
		if (!d || (d.length < 2 && !/[$€£]/.test(m[0]))) continue; // single digits match anything
		const re = new RegExp(`(?<![\\d.])${d.replace(".", "\\.")}(?:\\.0+)?(?!\\d)`);
		if (!re.test(corpus)) out.add(m[0].trim());
	}
	return [...out];
}

// Jev decides first: a probability per message, ~$0.00001 a call. Qwen is the fallback.
// On 50 messages (ai-stack evals/pichat: 25 written, 25 from real chats) chat scored ≤0.16 but
// for one opinion question (0.51); lookups missed at 0.6 were short follow-ups to a lookup
// ("his wives or sisters" 0.26, "look it up...." 0.48) and research asks (0.42, 0.46). A
// lookup sent to chat gets a made-up answer; a chat message sent to lookup only costs time.
// So the cutoff is low, and lower still right after a lookup.
const JEV_URL = process.env.PICHAT_JEV_URL ?? `${GATEWAY.replace(/\/v1$/, "")}/openrouter/decisions`;
const JEV_AT = Number(process.env.PICHAT_JEV_AT ?? 0.4);
const JEV_FOLLOW_AT = Number(process.env.PICHAT_JEV_FOLLOW_AT ?? 0.2);
const JEV_Q =
	"Answering this message well needs information from the web: facts, links, products, prices, specs, " +
	"recommendations of things to buy or watch, how-tos, news, dates, or details of books, shows, games or anime. " +
	"It is not small talk, feelings, opinions, jokes, roleplay, story writing, or something answered from the conversation itself.";

async function decideJev(prompt: string, lastReply: string, lastMode: Mode, signal?: AbortSignal): Promise<Mode> {
	const state = [
		...(lastReply ? [`The assistant's previous reply:\n${lastReply.slice(-1500)}`] : []),
		`The user's new message in a chat app:\n${prompt.slice(0, 4000)}`,
	];
	return (await jevSays(state, JEV_Q, signal)) >= (lastMode === "look" ? JEV_FOLLOW_AT : JEV_AT) ? "look" : "chat";
}

async function jevSays(state: string[], q: string, signal?: AbortSignal): Promise<number> {
	const res = await fetch(JEV_URL, {
		method: "POST",
		headers: { "content-type": "application/json" },
		body: JSON.stringify({ model: "typesafe/jev-1.14", state, questions: { q: { type: "noul", instructions: q } } }),
		signal: signal ? AbortSignal.any([signal, AbortSignal.timeout(10_000)]) : AbortSignal.timeout(10_000),
	});
	if (!res.ok) throw new Error(`jev ${res.status}`);
	const p = Number(((await res.json()) as { answers?: { q?: { noul?: number } } }).answers?.q?.noul);
	if (!Number.isFinite(p)) throw new Error("jev: no answer");
	return p;
}

/** Do this message's passages so far answer it? Unsure (Jev down) counts as no. */
async function enough(prompt: string, found: string[], signal?: AbortSignal): Promise<boolean> {
	if (!(ENOUGH_AT > 0)) return false;
	try {
		const state = [`The user's message in a chat app:\n${prompt.slice(0, 3000)}`, `Passages found so far:\n${found.join("\n\n").slice(-9000)}`];
		return (await jevSays(state, ENOUGH_Q, signal)) >= ENOUGH_AT;
	} catch {
		return false;
	}
}

async function decide(prompt: string, lastReply: string, lastMode: Mode, signal?: AbortSignal): Promise<Mode> {
	if (process.env.PICHAT_DECIDER !== "qwen") {
		try {
			return await decideJev(prompt, lastReply, lastMode, signal);
		} catch {
			// Jev unreachable: the local planner decides
		}
	}
	return decideQwen(prompt, lastReply, signal);
}

async function decideQwen(prompt: string, lastReply: string, signal?: AbortSignal): Promise<Mode> {
	const context = lastReply ? `Previous assistant reply (for context):\n${lastReply.slice(-1500)}\n\n` : "";
	try {
		const res = await fetch(`${GATEWAY}/chat/completions`, {
			method: "POST",
			headers: { "content-type": "application/json", authorization: "Bearer local" },
			body: JSON.stringify({
				model: PLANNER,
				max_tokens: 4,
				temperature: 0,
				chat_template_kwargs: { enable_thinking: false },
				messages: [
					{ role: "system", content: DECIDE },
					{ role: "user", content: `${context}New message:\n${prompt.slice(0, 4000)}\n\nLOOKUP or CHAT?` },
				],
			}),
			signal: signal ?? AbortSignal.timeout(30_000),
		});
		const data = (await res.json()) as { choices?: { message?: { content?: string } }[] };
		return /look/i.test(data.choices?.[0]?.message?.content ?? "") ? "look" : "chat";
	} catch {
		return "chat"; // planner unreachable: Bolt still answers
	}
}

export default function (pi: ExtensionAPI) {
	let mode: Mode = "chat";
	let lastReply = "";
	// URLs in this session's tool results (filled from the context too, so a resumed chat's
	// earlier pages still count): a link is kept only if a lookup returned it.
	const seen = new Set<string>();
	const pages = new Set<string>(); // the text of those tool results, for the number check
	const addPage = (text: string) => {
		if (!text || pages.has(text)) return;
		pages.add(text);
		for (const u of text.match(URL_RE) ?? []) seen.add(norm(u));
	};
	let prompt = "";
	let looks = 0; // lookups and digs for this message
	let found: string[] = []; // their results
	let stop = false; // enough found: lookups are off until the next message

	pi.on("message_end", (event) => {
		const m = event.message as { role?: string; content?: unknown };
		if (!Array.isArray(m.content)) return;
		const blocks = m.content as { type?: string; text?: string }[];
		if (m.role === "toolResult") {
			addPage(textOf(blocks));
			return;
		}
		if (m.role !== "assistant") return;
		let removed = 0;
		const content =
			mode === "look"
				? blocks.map((b) => {
						if (b.type !== "text" || !b.text) return b;
						const r = stripUnseenLinks(b.text, seen);
						removed += r.removed;
						return { ...b, text: r.text };
					})
				: blocks;
		const text = content.flatMap((b) => (b.type === "text" && b.text ? [b.text] : [])).join("\n");
		if (text) lastReply = text;
		const final = (m as { stopReason?: string }).stopReason === "stop";
		const nums = mode === "look" && final && text ? unseenNumbers(text, [...pages].join("\n").replace(/(\d),(\d)/g, "$1$2")) : [];
		if (!removed && !nums.length) return;
		const notes = [
			...(removed ? [`${removed} link${removed > 1 ? "s" : ""} taken out: not in the pages the lookup found.`] : []),
			...(nums.length
				? [`Not in the pages found: ${nums.slice(0, 12).join(", ")}. Some may be totals or estimates; check them before relying on them.`]
				: []),
		];
		const last = content.findLastIndex((b) => b.type === "text");
		content[last] = { ...content[last], text: content[last].text + notes.map((n) => `\n\n_(${n})_`).join("") };
		return { message: { ...(event.message as object), content } as typeof event.message };
	});

	pi.on("before_agent_start", async (event, ctx) => {
		if (event.messageType !== "user") return;
		if (ctx.model?.provider !== PROVIDER || ctx.model?.id !== "pichat") return;
		prompt = event.prompt.trim();
		looks = 0;
		found = [];
		stop = false;
		if (event.images?.length) mode = "chat";
		else if (prompt.startsWith("?")) mode = "look";
		else mode = await decide(prompt, lastReply, mode, ctx.signal);
		pi.setActiveTools(mode === "look" ? LOOK_TOOLS : CHAT_TOOLS);
		if (ctx.hasUI) ctx.ui.setStatus("pichat", mode === "look" ? "looking it up" : undefined);
		if (mode === "look") return { systemPrompt: event.systemPrompt + LOOK_GUIDE };
	});

	// Before each model call: note every URL tool results gave, and stub the lookups of messages
	// already answered (everything before the last user message).
	pi.on("context", (event) => {
		const msgs = event.messages as Msg[];
		const lastUser = msgs.findLastIndex((m) => m.role === "user");
		let changed = false;
		const out = msgs.map((m, i) => {
			if (m.role !== "toolResult") return m;
			const text = textOf(m.content);
			addPage(text);
			if (!PRUNE || i > lastUser || !LOOKERS.has(m.toolName ?? "") || text.length < 600) return m;
			changed = true;
			return stub(m, text);
		});
		if (changed) return { messages: out as typeof event.messages };
	});

	// After each lookup: stop looking once the passages answer the message, or after MAX_LOOKS.
	pi.on("tool_result", async (event, ctx) => {
		if (mode !== "look" || !LOOKERS.has(event.toolName) || event.isError) return;
		looks++;
		found.push(textOf(event.content));
		if (stop) return;
		const capped = looks >= MAX_LOOKS;
		if (!capped && !(await enough(prompt, found, ctx.signal))) return;
		// lookup and dig go: the planner ignored the note and tried again, a wasted ~7 s step,
		// against ~2 s to reprocess the prompt once the tool list changes. The block backs it up.
		stop = true;
		pi.setActiveTools(NOTES);
		const why = capped ? `That's ${looks} lookups for this message, the most allowed.` : "These passages cover the message.";
		return {
			content: [...event.content, { type: "text" as const, text: `\n\n(${why} Write the answer now from what was found, and say what it didn't cover.)` }],
			details: event.details,
		};
	});

	pi.on("tool_call", (event) => {
		if (stop && LOOKERS.has(event.toolName))
			return { block: true, reason: "Enough has been looked up for this message. Answer from the passages you have and say what they didn't cover." };
	});

	pi.on("agent_end", (_event, ctx) => {
		if (ctx.hasUI) ctx.ui.setStatus("pichat", undefined);
	});

	pi.registerVirtualModel({
		provider: PROVIDER,
		id: "pichat",
		name: "pichat (Bolt talks, Qwen looks things up)",
		thinkingLevels: ["off", "low"],
		contextWindow: 32768,
		maxTokens: 8192,
		route(request, ctx) {
			const id = request.reason === "direct" ? TALKER : mode === "look" ? PLANNER : TALKER;
			const model = ctx.modelRegistry.find(PROVIDER, id);
			if (!model) throw new Error(`${PROVIDER}/${id} is not in models.json`);
			// Bolt chats without thinking; the planner thinks a little (2k budget on the server).
			return { model, thinkingLevel: id === PLANNER ? "low" : "off" };
		},
	});
}
