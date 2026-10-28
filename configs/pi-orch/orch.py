#!/usr/bin/env python3
"""Run `reader` workers over the slices in a ledger, check their claims, and digest them.

The brain plans by writing <notes>/ledger.json (ai-stack docs/ORCHESTRATE-PLAN.md, v2):
  {"goal": "how a request flows from X to Y",
   "root": "/path/to/project",
   "slices": [{"id": "s1", "file": "src/http.rs", "lines": [1, 400],
               "questions": ["Which function handles POST /search?"]}]}
After that this script owns each slice's status (pending, running, done, failed; the brain
may set redo, or add new pending slices). Claims files and logs go next to the ledger.

  pi-orch check LEDGER    validate the plan and fill in defaults
  pi-orch run LEDGER      run pending/redo slices, 2 at a time, then a gap pass, then write
                          the digest [--jobs N] [--tries N] [--model M] [--thinking T]
                          [--think-budget N] [--agent NAME|FILE] [--only s1,s2]
                          [--gaps jev|rule|off] [--gap-share F]
  pi-orch status LEDGER   one line per slice
  pi-orch digest LEDGER   write <notes>/digest.md: the checked claims per slice, for the brain

Each worker is one chat call through the gateway (PI_ORCH_GATEWAY, default desktop:4000),
with the agent file's model and prompt; its brief holds the slice's lines, numbered, and the
reply is held to the claims JSON schema and saved as the claims file. Not Pi: Pi's own
system prompt says the model reads files and runs commands, and with no tools Flint then
wrote tool calls as text and stopped (most failed tries); direct calls answered 36 of 36
(eval, 2026-10-28). The claims go through checkrefs; a slice with no claims, or with no or
mostly unfound quotes, is retried once with what was missing.

Gap pass: one pass misses about half of what matters, and a different half each time (eval,
2026-10-28), while its quotes are right. So after the slices are done, each slice's 5-line
blocks are ranked against the goal (or the ledger's optional "focus") by Jev, a decision
model behind the gateway (a plain rule if it can't be reached), less a penalty per claim
already in the block; the top ones, up to --gap-share of the slice's lines, go to one more
worker as slice <id>g ("ranges" instead of one span).
Standard library only.
"""
import argparse
import ast
import concurrent.futures as cf
import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request

AGENTS_DIR = os.path.expanduser("~/.pi/agent/agents")
RUNNABLE = ("pending", "redo")
VERIFIED = ("exact", "fixed")
DROPPED = ("missing", "nofile", "short")
MAX_LINES = 800
# A worker writes about 10 claims per call however long its slice (eval), so a long slice
# loses facts: the brain made all 523 lines of orch.py one slice and found 10/24 where two
# smaller slices found 15-16. Longer pending slices are split into equal parts.
SPLIT_AT = 250
# Gap pass blocks: 5 lines, and a block with claims is ranked lower, not skipped. With 10-line
# blocks skipped once any claim landed in them, dense code hid its other facts: on the flow
# question 35% of pass-1 misses fell in the gap ranges, 76% this way (81% vs 64% on limits).
BLOCK = 5
COVERED_PENALTY = 1.5  # per verified claim in the block, on Jev's 0-4 scale
GAP_TIMEOUT = 120  # seconds per gap worker, one try: a stuck one cost 5 minutes for nothing (eval)
GATEWAY = os.environ.get("PI_ORCH_GATEWAY", "http://desktop:4000/v1")
CLAIMS_SCHEMA = {
    "type": "object",
    "properties": {
        "claims": {"type": "array", "items": {
            "type": "object",
            "properties": {"claim": {"type": "string"}, "file": {"type": "string"},
                           "line": {"type": "integer"}, "quote": {"type": "string"}},
            "required": ["claim", "file", "line", "quote"]}},
        "open_questions": {"type": "array", "items": {"type": "string"}},
        "notes": {"type": "string"},
        "garbled": {"type": "boolean"},
    },
    "required": ["claims"],
}
JEV_URL = os.environ.get("PI_ORCH_JEV_URL", "http://desktop:4000/openrouter/decisions")
JEV_MODEL = os.environ.get("PI_ORCH_JEV_MODEL", "typesafe/jev-1.14")

lock = threading.Lock()


def die(msg):
    print(f"pi-orch: {msg}", file=sys.stderr)
    sys.exit(2)


# --- ledger ---------------------------------------------------------------------------

def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        die(f"can't read {path}: {e}")


def save(path, ledger):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".ledger-")
    out = {**ledger, "slices": [{k: v for k, v in s.items() if not k.startswith("_")} for s in ledger["slices"]]}
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)
        f.write("\n")
    os.replace(tmp, path)


def notes_dir(path):
    return os.path.dirname(os.path.abspath(path))


def count_lines(path):
    with open(path, "rb") as f:
        return sum(1 for _ in f)


def validate(path, ledger):
    """Problems with the plan (empty when runnable); fills in defaults and absolute root."""
    problems = []
    if not isinstance(ledger, dict) or not isinstance(ledger.get("slices"), list):
        return ['the ledger must be {"goal", "root", "slices": [...]}']
    if not str(ledger.get("goal") or "").strip():
        problems.append("no goal")
    root = os.path.join(notes_dir(path), os.path.expanduser(str(ledger.get("root") or ".")))
    ledger["root"] = root = os.path.abspath(root)
    if not os.path.isdir(root):
        problems.append(f"root {root} isn't a folder")
    seen = set()
    for i, s in enumerate(ledger["slices"]):
        if not isinstance(s, dict):
            problems.append(f"slice {i + 1} isn't an object")
            continue
        sid = str(s.get("id") or "")
        where = f"slice {sid or i + 1}"
        if not sid or not sid.replace("-", "").replace("_", "").isalnum():
            problems.append(f"{where}: id must be letters, digits, - or _")
        elif sid in seen:
            problems.append(f"{where}: duplicate id")
        seen.add(sid)
        qs = s.get("questions")
        if not isinstance(qs, list) or not qs or not all(isinstance(q, str) and q.strip() for q in qs):
            problems.append(f"{where}: questions must be a non-empty list of strings")
        f = str(s.get("file") or "")
        full = os.path.join(root, f)
        if not f or os.path.isabs(f) or not os.path.isfile(full):
            problems.append(f"{where}: file {f!r} isn't a file under root")
            continue
        n = count_lines(full)
        lines = s.get("lines") or [1, n]
        if not (isinstance(lines, list) and len(lines) == 2 and all(isinstance(x, int) for x in lines)
                and 1 <= lines[0] <= lines[1]):
            problems.append(f"{where}: lines must be [first, last]")
            continue
        if lines[0] > n:
            problems.append(f"{where}: starts at line {lines[0]} but {f} has {n} lines")
            continue
        s["lines"] = [lines[0], min(lines[1], n)]
        rs = s.get("ranges")
        if rs is not None and not (isinstance(rs, list) and rs and all(
                isinstance(r, list) and len(r) == 2 and all(isinstance(x, int) for x in r)
                and 1 <= r[0] <= r[1] <= n for r in rs)):
            problems.append(f"{where}: ranges must be [[first, last], ...] inside the file")
            continue
        if rs is not None and sum(b - a + 1 for a, b in rs) > MAX_LINES:
            problems.append(f"{where}: ranges cover more than {MAX_LINES} lines")
        elif rs is None and s["lines"][1] - s["lines"][0] + 1 > MAX_LINES:
            problems.append(f"{where}: {s['lines'][1] - s['lines'][0] + 1} lines; split it (at most {MAX_LINES})")
        s.setdefault("status", "pending")
        s.setdefault("attempts", 0)
        s.setdefault("tries", [])
        if s["status"] not in ("pending", "running", "done", "failed", "redo"):
            problems.append(f"{where}: unknown status {s['status']!r}")
    if not problems:
        ledger["slices"] = [part for s in ledger["slices"] for part in split(s, seen)]
    return problems


def split(s, ids):
    """A long untouched slice as equal parts of at most SPLIT_AT lines (ids s1a, s1b, ...)."""
    a, b = s["lines"]
    n = b - a + 1
    if s.get("ranges") or s.get("of") or s["attempts"] or s["status"] not in RUNNABLE or n <= SPLIT_AT:
        return [s]
    k = -(-n // SPLIT_AT)
    parts, start = [], a
    for i in range(k):
        end = a + (n * (i + 1)) // k - 1
        pid = next(f"{s['id']}{c}" for c in "abcdefghijklmnopqrstuvwxyz" if f"{s['id']}{c}" not in ids)
        ids.add(pid)
        parts.append({**s, "id": pid, "lines": [start, end], "split_from": s["id"], "tries": []})
        start = end + 1
    return parts


# --- workers --------------------------------------------------------------------------

def agent_file(name):
    path = name if name.endswith(".md") or "/" in name else os.path.join(AGENTS_DIR, f"{name}.md")
    try:
        with open(os.path.expanduser(path), encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        die(f"can't read agent {name}: {e}")
    meta, body = {}, text
    if text.startswith("---\n"):
        head, _, body = text[4:].partition("\n---\n")
        for line in head.splitlines():
            k, sep, v = line.partition(":")
            if sep:
                meta[k.strip()] = v.strip()
    meta["prompt"] = body.strip()
    return meta


def checkrefs_cmd():
    if os.environ.get("PI_ORCH_CHECKREFS"):
        return [os.environ["PI_ORCH_CHECKREFS"]]
    if shutil.which("checkrefs"):
        return ["checkrefs"]
    return [sys.executable, "-I", os.path.join(os.path.dirname(os.path.abspath(__file__)), "checkrefs.py")]


def ranges(s):
    return s.get("ranges") or [s["lines"]]


def where(s):
    return ", ".join(f"{a}-{b}" for a, b in ranges(s))


def brief(ledger, s, claims, last):
    qs = "\n".join(f"{i + 1}. {q}" for i, q in enumerate(s["questions"]))
    # The slice goes in the brief, numbered: a worker left to find and read it spent 14 turns
    # (find /, other files, sed paging past the read cap) on 160 lines.
    with open(os.path.join(ledger["root"], s["file"]), encoding="utf-8", errors="replace") as f:
        lines = f.readlines()
    # Between ranges a plain note, not "...": workers read the gaps as garbled code.
    code = "".join(
        (f"(lines {ranges(s)[i - 1][1] + 1}-{a - 1} left out: another worker covered them)\n" if i else "")
        + "".join(f"{n}\t{lines[n - 1]}" for n in range(a, b + 1))
        for i, (a, b) in enumerate(ranges(s)))
    if s.get("of"):
        ask = (f"Another worker read {s['file']} for these questions:\n{qs}\n\n"
               "Its claims were mostly about other lines. The lines below got few or none, yet may bear "
               "on the job. "
               "Give one claim for every fact in them that does: values and defaults, conditions, "
               "what is refused, retried, stopped, failed or checked, and what calls what. Don't "
               "stop at a few. If nothing here bears on the job, reply {\"claims\": []}. These lines "
               "are all you need: you can't read files, so write no tool calls.\n\n")
    else:
        ask = f"Answer:\n{qs}\n\n"
    text = (
        f"Slice {s['id']} of a larger job. The job: {ledger['goal']}\n\n"
        f"{ask}"
        "Reply with only the claims JSON.\n"
        f"Use \"file\": \"{s['file']}\" in every claim. Each fact is a claim with its line number "
        "and a quote copied from that line (the text after the tab, not the number). If a "
        "question isn't answered in these lines, say so in open_questions, with the name of the "
        "function or file where the answer probably is.\n\n"
        f"{s['file']}, lines {where(s)}, each line as <number><tab><text>:\n```\n{code}```"
    )
    if last:
        text += f"\n\nThis is another try at this slice. Last time: {'; '.join(last['reasons'])}."
        if last.get("unfound"):
            text += (" These quotes weren't found in the file, so those claims were thrown away; "
                     "copy quotes from the code above, or leave the claim out:\n"
                     + "\n".join(f"- {c['file']}:{c['line']} {c['quote']!r}" for c in last["unfound"][:8]))
        if last.get("kept"):
            text += f"\n{last['kept']} claims from last time were verified and are kept; you needn't repeat them."
    return text


def run_worker(ledger, s, claims, log, agent, opts, last):
    """One worker: a single chat call through the gateway, the reply held to the claims schema.
    Returns what it did (stop reason, turns, tokens, seconds, reply)."""
    model = opts.model or agent.get("model") or "desktop/flint"
    # Pi's names are provider/model; the gateway knows the model part (desktop/flint -> flint).
    name = model.split("/", 1)[1] if model.startswith("desktop/") else model
    body = {"model": name, "max_tokens": 16384,
            "messages": [{"role": "system", "content": agent["prompt"]},
                         {"role": "user", "content": f"Task: {brief(ledger, s, claims, last)}"}],
            "response_format": {"type": "json_schema", "json_schema": {"name": "claims", "schema": CLAIMS_SCHEMA}}}
    if opts.thinking:
        body["reasoning_effort"] = opts.thinking
    if opts.think_budget:  # llama.cpp's per-request cap on thinking tokens (Flint's server default: 2048)
        body["thinking_budget_tokens"] = opts.think_budget
    timeout = GAP_TIMEOUT if s.get("of") else float(agent.get("timeout") or 15) * 60
    info = {"model": model, "stop": None, "turns": 1, "input": 0, "output": 0, "reply": ""}
    start = time.time()
    req = urllib.request.Request(f"{GATEWAY}/chat/completions", json.dumps(body).encode(),
                                 {"Content-Type": "application/json"})
    with open(log, "w", encoding="utf-8") as logf:
        logf.write(json.dumps({"request": body}) + "\n")
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.load(r)
            logf.write(json.dumps({"response": d}) + "\n")
            choice = d["choices"][0]
            u = d.get("usage") or {}
            info.update(stop=choice.get("finish_reason"), input=u.get("prompt_tokens") or 0,
                        output=u.get("completion_tokens") or 0,
                        reply=(choice["message"].get("content") or "").strip())
        except Exception as e:  # noqa: BLE001 - timeouts, HTTP errors, bad JSON: the slice is retried
            if isinstance(e, TimeoutError) or isinstance(getattr(e, "reason", None), TimeoutError):
                info["stop"] = "timeout"
            detail = getattr(e, "read", lambda: b"")()
            info["error"] = f"{e} {detail[:200].decode(errors='replace')}".strip()[:300]
            logf.write(json.dumps({"error": info["error"]}) + "\n")
    info["seconds"] = round(time.time() - start)
    return info


def check_claims(ledger, claims):
    """checkrefs on one claims file: (parsed file or None, checked claims)."""
    try:
        with open(claims, encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict) or not isinstance(data.get("claims"), list):
            return None, []
    except (OSError, ValueError):
        return None, []
    subprocess.run(checkrefs_cmd() + ["--root", ledger["root"], "--write", claims],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        with open(checked_path(claims), encoding="utf-8") as f:
            return data, json.load(f)
    except (OSError, ValueError):
        return data, []


def checked_path(claims):
    return claims[:-5] + ".checked.json"


def literal(text):
    """JSON as Flint writes it: Python-style literals are allowed ('single-quoted' strings,
    which it uses for quotes containing "). Parsed with ast, never evaluated."""
    names = {"true": True, "false": False, "null": None, "True": True, "False": False, "None": None}

    def conv(n):
        if isinstance(n, ast.Constant) and isinstance(n.value, (str, int, float, bool, type(None))):
            return n.value
        if isinstance(n, ast.Name) and n.id in names:
            return names[n.id]
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, ast.USub) and isinstance(n.operand, ast.Constant):
            return -n.operand.value
        if isinstance(n, (ast.List, ast.Tuple)):
            return [conv(x) for x in n.elts]
        if isinstance(n, ast.Dict) and None not in n.keys:
            return {str(conv(k)): conv(v) for k, v in zip(n.keys, n.values)}
        raise ValueError(f"not a literal: {type(n).__name__}")

    return conv(ast.parse(text.strip(), mode="eval").body)


def salvage(reply):
    """The claims that parse on their own, when the reply as a whole doesn't: Flint sometimes
    breaks one claim (`"file": "x".replace(...)`, a list closed early) and that cost the rest."""
    out, dec = [], json.JSONDecoder()
    for m in re.finditer(r'\{\s*"claim"\s*:', reply):
        try:
            c = dec.raw_decode(reply, m.start())[0]
        except ValueError:
            depth, end, q = 0, None, None  # find the matching brace, skipping strings
            i = m.start()
            while i < len(reply):
                ch = reply[i]
                if q:
                    if ch == "\\":
                        i += 1
                    elif ch == q:
                        q = None
                elif ch in "\"'":
                    q = ch
                elif ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        end = i + 1
                        break
                i += 1
            try:
                c = literal(reply[m.start():end]) if end else None
            except (ValueError, SyntaxError, TypeError, RecursionError, MemoryError):
                c = None
        if isinstance(c, dict) and all(k in c for k in ("claim", "file", "line", "quote")):
            out.append(c)
    return {"claims": out}


def save_reply(reply, claims):
    """Save the JSON object in a worker's reply (bare or fenced) as its claims file."""
    a, b = reply.find("{"), reply.rfind("}")
    if a < 0 or b < a:
        return
    try:
        data = json.loads(reply[a:b + 1])
    except ValueError:
        try:
            data = literal(reply[a:b + 1])
        except (ValueError, SyntaxError, TypeError, RecursionError, MemoryError):
            data = salvage(reply)
            if not data["claims"]:
                return
    with open(claims, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)


def tally(checked):
    out = {"verified": 0, "flagged": 0, "dropped": 0}
    for c in checked:
        st = c.get("status")
        if st in DROPPED:
            out["dropped"] += 1
        elif st in VERIFIED and not c.get("numbers"):
            out["verified"] += 1
        else:
            out["flagged"] += 1
    return out


def do_slice(path, ledger, sid, agent, opts):
    s = next(x for x in ledger["slices"] if x["id"] == sid)
    notes = notes_dir(path)
    os.makedirs(os.path.join(notes, "logs"), exist_ok=True)
    last = None
    for _ in range(1 if s.get("of") else opts.tries):  # a gap slice is extra: one try
        with lock:
            s["attempts"] += 1
            n = s["attempts"]
            s["status"] = "running"
            claims = os.path.join(notes, f"{sid}.try{n}.json")
            save(path, ledger)
        say(f"{sid} try {n}: {s['file']}:{where(s)}")
        if os.path.exists(claims):
            os.unlink(claims)
        info = run_worker(ledger, s, claims, os.path.join(notes, "logs", f"{sid}.try{n}.jsonl"), agent, opts, last)
        save_reply(info["reply"], claims)
        data, checked = check_claims(ledger, claims)
        counts = tally(checked)
        reasons = []
        if data is None:
            reasons.append(f"no valid claims file (the worker stopped: {info.get('error') or info['stop'] or 'exit ' + str(info.get('exit'))})")
        elif data.get("garbled") is True and not s.get("of"):
            reasons.append("the worker reported garbled code")
        elif not checked and not s.get("of"):  # a gap slice may hold nothing relevant
            reasons.append("no claims")
        elif checked and counts["verified"] + counts["flagged"] == 0:
            reasons.append("none of the quotes were found in the file")
        elif counts["dropped"] > counts["verified"] + counts["flagged"]:
            reasons.append(f"{counts['dropped']} of {len(checked)} quotes weren't found in the file")
        with lock:
            s["tries"].append({"try": n, "claims": os.path.basename(claims), **counts,
                               **({"problem": "; ".join(reasons)} if reasons else {}),
                               **{k: info[k] for k in ("model", "stop", "turns", "input", "output", "seconds") if k in info}})
            s["claims"] = os.path.basename(claims)
            kept = sum(t["verified"] + t["flagged"] for t in s["tries"])
            s["verified"] = sum(t["verified"] for t in s["tries"])
            garbled = data is not None and data.get("garbled") is True and not s.get("of")
            if not reasons or garbled:
                s["status"] = "failed" if garbled else "done"
            save(path, ledger)
        took = f"{info['seconds'] // 60}m{info['seconds'] % 60:02d}s, {info['turns']} turns"
        say(f"{sid} try {n}: {counts['verified']} verified, {counts['flagged']} flagged, "
            f"{counts['dropped']} dropped ({took})" + (f"; {'; '.join(reasons)}" if reasons else ""))
        if not reasons or garbled:
            return
        last = {"reasons": reasons, "kept": kept,
                "unfound": [c for c in checked if c.get("status") == "missing"]}
    with lock:
        s["status"] = "done" if kept else "failed"
        save(path, ledger)


def say(msg):
    with lock:
        print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


# --- gap pass -------------------------------------------------------------------------

JEV_LEVELS = [
    "Nothing here bears on the question.",
    "Background only: helps understand the code, but answers no part of the question.",
    "Relevant: part of what the question asks about.",
    "Directly answers part of the question.",
]
# The fallback when Jev can't be reached: lines that set values or decide outcomes.
RULE = re.compile(r"\b\d{2,}\b|\d_\d|process\.env|os\.environ|getenv|\b(if|elif|unless|while|case)\b.*"
                  r"(return|raise|throw|break|continue|exit)|\b(raise|throw|abort|kill|reject|refus|retry|"
                  r"timeout|limit|max|min|fail|block)", re.I)


def rule_rank(code):
    return sum(bool(RULE.search(line)) for line in code.splitlines()) / 3


def jev_rank(question, where_, code):
    """0-4: Jev's score on JEV_LEVELS plus its yes-probability that the lines answer part of it."""
    body = {"model": JEV_MODEL,
            "state": [f"Question about this code base: {question}", f"{where_} (number, tab, text):\n{code}"],
            "questions": {"rel": {"type": "score", "instructions": "How much do these lines bear on the question?",
                                  "criteria": JEV_LEVELS},
                          "part": {"type": "noul", "instructions": f"These lines answer part of this question: {question}"}}}
    req = urllib.request.Request(JEV_URL, json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        ans = json.load(r)["answers"]
    return float(ans["rel"]["score"]) + float(ans["part"]["noul"])


def plan_gaps(ledger, how, share):
    """Add a gap slice <id>g for each finished slice that has none yet: its blocks ranked by
    relevance less COVERED_PENALTY per claim already in them, best first, up to `share` of its
    lines. Returns the new slice ids."""
    covered = {}
    for s in ledger["slices"]:
        for c in s.get("_checked", []):
            if c.get("status") in VERIFIED:
                covered.setdefault(c.get("file"), []).append(c.get("line"))
    have = {s.get("of") for s in ledger["slices"]}
    files, blocks = {}, []
    for s in ledger["slices"]:
        if s.get("of") or s["id"] in have or s.get("status") != "done":
            continue
        if s["file"] not in files:
            with open(os.path.join(ledger["root"], s["file"]), encoding="utf-8", errors="replace") as f:
                files[s["file"]] = f.read().splitlines()
        lines = files[s["file"]]
        hit = covered.get(s["file"], [])
        for a, b in ranges(s):
            for x in range(a, b + 1, BLOCK):
                y = min(x + BLOCK - 1, b)
                code = "\n".join(f"{n}\t{lines[n - 1]}" for n in range(x, y + 1))
                blocks.append({"sid": s["id"], "file": s["file"], "a": x, "b": y, "code": code,
                               "claims": sum(x <= n <= y for n in hit)})
    if not blocks:
        return []
    question = ledger.get("focus") or ledger["goal"]

    def rank(bl):
        if how == "jev":
            try:
                return jev_rank(question, f"Lines {bl['a']}-{bl['b']} of {bl['file']}", bl["code"]), "jev"
            except Exception:  # noqa: BLE001 - any failure falls back to the rule
                pass
        return rule_rank(bl["code"]), "rule"

    start = time.time()
    with cf.ThreadPoolExecutor(8) as ex:
        for bl, (r, by) in zip(blocks, ex.map(rank, blocks)):
            bl["rank"], bl["by"] = r - COVERED_PENALTY * bl["claims"], by
    by = {bl["by"] for bl in blocks}
    say(f"gaps: ranked {len(blocks)} blocks by {'/'.join(sorted(by))} in {time.time() - start:.0f}s")
    new = []
    for s in [x for x in ledger["slices"] if any(bl["sid"] == x["id"] for bl in blocks)]:
        mine = sorted((bl for bl in blocks if bl["sid"] == s["id"]), key=lambda bl: -bl["rank"])
        budget = share * sum(b - a + 1 for a, b in ranges(s))
        pick, used = [], 0
        for bl in mine:
            if used + bl["b"] - bl["a"] + 1 > budget:
                break
            pick.append([bl["a"], bl["b"]])
            used += bl["b"] - bl["a"] + 1
        if not pick:
            continue
        merged = []
        for a, b in sorted(pick):
            if merged and a <= merged[-1][1] + 1:
                merged[-1][1] = max(merged[-1][1], b)
            else:
                merged.append([a, b])
        gid = f"{s['id']}g"
        ledger["slices"].append({"id": gid, "of": s["id"], "file": s["file"], "questions": s["questions"],
                                 "lines": [merged[0][0], merged[-1][1]], "ranges": merged,
                                 "status": "pending", "attempts": 0, "tries": []})
        new.append(gid)
    return new


def load_checked(path, ledger):
    """Each slice's checked claims, in memory (`_checked`, never saved) for the gap pass."""
    notes = notes_dir(path)
    for s in ledger["slices"]:
        s["_checked"] = []
        for t in s.get("tries", []):
            try:
                with open(checked_path(os.path.join(notes, t["claims"])), encoding="utf-8") as f:
                    s["_checked"] += json.load(f)
            except (OSError, ValueError):
                pass


# --- commands -------------------------------------------------------------------------

def cmd_check(a):
    ledger = load(a.ledger)
    problems = validate(a.ledger, ledger)
    for p in problems:
        print(f"- {p}")
    if problems:
        sys.exit(1)
    save(a.ledger, ledger)
    print(f"ok: {len(ledger['slices'])} slices under {ledger['root']}")


def cmd_run(a):
    agent = agent_file(a.agent)
    lockf = open(a.ledger + ".lock", "w")
    try:
        fcntl.flock(lockf, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        die(f"another pi-orch run has {a.ledger}")
    ledger = load(a.ledger)
    problems = validate(a.ledger, ledger)
    if problems:
        die("the ledger has problems (pi-orch check):\n" + "\n".join(f"- {p}" for p in problems))
    only = set(a.only.split(",")) if a.only else None
    for s in ledger["slices"]:
        if s["status"] == "running":
            s["status"] = "pending"  # left over from a run that was stopped
    save(a.ledger, ledger)
    todo = [s["id"] for s in ledger["slices"] if s["status"] in RUNNABLE and (only is None or s["id"] in only)]
    if not todo:
        print("nothing to run")
    else:
        print(f"{len(todo)} slices, {a.jobs} at a time, model {a.model or agent.get('model')}", flush=True)
        run_pool(a, ledger, agent, todo)
    if a.gaps != "off":
        load_checked(a.ledger, ledger)  # no workers are running now, so no lock (say() takes it)
        gaps = plan_gaps(ledger, a.gaps, a.gap_share)
        save(a.ledger, ledger)
        if only is not None:
            gaps = [g for g in gaps if g[:-1] in only]
        if gaps:
            say(f"gap pass: {len(gaps)} slices")
            run_pool(a, ledger, agent, gaps)
    status(ledger)
    print(f"digest: {write_digest(a.ledger, ledger)}")


def run_pool(a, ledger, agent, todo):
    pool = cf.ThreadPoolExecutor(a.jobs)
    futs = {pool.submit(do_slice, a.ledger, ledger, sid, agent, a): sid for sid in todo}
    try:
        pending = set(futs)
        while pending:
            done, pending = cf.wait(pending, timeout=1)
            for f in done:
                if f.exception():
                    say(f"{futs[f]}: runner error: {f.exception()!r}")
    except KeyboardInterrupt:
        pool.shutdown(wait=False, cancel_futures=True)
        with lock:
            for s in ledger["slices"]:
                if s["status"] == "running":
                    s["status"] = "pending"
            save(a.ledger, ledger)
        print("pi-orch: stopped; running slices are back to pending", file=sys.stderr, flush=True)
        os._exit(2)  # workers are blocked in HTTP calls; don't wait for them
    pool.shutdown()


def status(ledger):
    tot = {"verified": 0, "flagged": 0, "dropped": 0}
    for s in ledger["slices"]:
        c = {k: sum(t[k] for t in s.get("tries", [])) for k in tot}
        for k in tot:
            tot[k] += c[k]
        print(f"{s['id']:<8} {s.get('status', 'pending'):<8} tries {s.get('attempts', 0)}  "
              f"{c['verified']:>3} ok {c['flagged']:>2} flagged {c['dropped']:>2} dropped  {s['file']}:{where(s)}")
    tries = sum(s.get("attempts", 0) for s in ledger["slices"])
    print(f"total: {len(ledger['slices'])} slices, {tries} tries, {tot['verified']} verified, "
          f"{tot['flagged']} flagged, {tot['dropped']} dropped")


def cmd_status(a):
    ledger = load(a.ledger)
    problems = validate(a.ledger, ledger)
    if problems:
        die("the ledger has problems (pi-orch check):\n" + "\n".join(f"- {p}" for p in problems))
    status(ledger)


def clip(s, n):
    s = " ".join(str(s).split())
    return s if len(s) <= n else s[: n - 1] + "…"


def write_digest(path, ledger):
    notes = notes_dir(path)
    out = [f"# Digest: {ledger['goal']}", "",
           "Claims from `reader` workers whose quote checkrefs found in the file (root: "
           f"`{ledger['root']}`), so they're verified: use them as they are. `[far]`: the quote "
           "is elsewhere in the file than cited; `[numbers N]`: the claim states a number its "
           "quote doesn't show. Check only those. Unfound quotes are left out and only counted.", ""]
    for s in ledger["slices"]:
        claims, seen, dropped, notes_text, opens = [], set(), 0, [], []
        for t in s.get("tries", []):
            cfile = os.path.join(notes, t["claims"])
            try:
                with open(checked_path(cfile), encoding="utf-8") as f:
                    checked = json.load(f)
            except (OSError, ValueError):
                checked = []
            try:
                with open(cfile, encoding="utf-8") as f:
                    raw = json.load(f)
                if raw.get("notes"):
                    notes_text.append(clip(raw["notes"], 600))
                opens += [clip(q, 200) for q in raw.get("open_questions") or [] if isinstance(q, str)]
            except (OSError, ValueError, AttributeError):
                pass
            for c in checked:
                if c.get("status") in DROPPED:
                    dropped += 1
                    continue
                key = (c.get("file"), c.get("line"), clip(c.get("claim", ""), 80))
                if key in seen:
                    continue
                seen.add(key)
                tag = " [far]" if c.get("status") == "far" else ""
                if c.get("numbers"):
                    tag += f" [numbers {', '.join(map(str, c['numbers']))}]"
                # No quote: checkrefs has checked it, and quotes doubled the digest (a brain
                # then read it in 25 pieces).
                claims.append(f"- {clip(c.get('claim', ''), 300)} — `{c.get('file')}:{c.get('line')}`{tag}")
        out.append(f"## {s['id']}: {s['file']}:{where(s)} ({s.get('status', 'pending')}, "
                   f"{s.get('attempts', 0)} tries, {len(claims)} claims, {dropped} dropped)")
        if s.get("of"):
            out.append(f"Gap pass of {s['of']}: lines it had no claims on, ranked by relevance to the goal")
        else:
            out.append("Questions: " + " / ".join(s["questions"]))
        last = (s.get("tries") or [{}])[-1]
        if last.get("problem"):
            out.append(f"Last try: {last['problem']}")
        out += claims or ["- (no checked claims)"]
        if notes_text:
            out.append(f"Worker notes: {notes_text[-1]}")
        if opens:
            out.append("Open: " + " / ".join(dict.fromkeys(opens)))
        out.append("")
    dest = os.path.join(notes, "digest.md")
    with open(dest, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    return dest


def cmd_digest(a):
    ledger = load(a.ledger)
    problems = validate(a.ledger, ledger)
    if problems:
        die("the ledger has problems (pi-orch check):\n" + "\n".join(f"- {p}" for p in problems))
    print(write_digest(a.ledger, ledger))


def main():
    ap = argparse.ArgumentParser(prog="pi-orch", description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("check", "run", "status", "digest"):
        p = sub.add_parser(name)
        p.add_argument("ledger")
        if name == "run":
            p.add_argument("--jobs", type=int, default=2, help="workers at once (Flint has 2 slots)")
            p.add_argument("--tries", type=int, default=2, help="tries per slice in this run")
            p.add_argument("--model", help="worker model instead of the agent file's (e.g. a hosted one)")
            p.add_argument("--thinking", help="reasoning_effort for the worker call (hosted models; Flint's budget is set on the server)")
            p.add_argument("--think-budget", type=int, help="most thinking tokens per worker call (llama.cpp models)")
            p.add_argument("--agent", default="reader", help="agent name in ~/.pi/agent/agents, or a .md path")
            p.add_argument("--only", help="comma-separated slice ids")
            p.add_argument("--gaps", choices=("jev", "rule", "off"), default="jev",
                           help="rank blocks with Jev (rule if unreachable), the rule alone, or skip the gap pass")
            p.add_argument("--gap-share", type=float, default=0.5,
                           help="most of each slice's lines a gap slice may hold (default 0.5)")
    a = ap.parse_args()
    a.ledger = os.path.abspath(a.ledger)
    if a.cmd == "run" and (a.jobs < 1 or a.tries < 1):
        die("--jobs and --tries must be at least 1")
    {"check": cmd_check, "run": cmd_run, "status": cmd_status, "digest": cmd_digest}[a.cmd](a)


if __name__ == "__main__":
    main()
