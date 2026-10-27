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
  pi-orch run LEDGER      run pending/redo slices, 2 at a time, then write the digest
                          [--jobs N] [--tries N] [--model M] [--thinking T] [--agent NAME|FILE]
                          [--only s1,s2]
  pi-orch status LEDGER   one line per slice
  pi-orch digest LEDGER   write <notes>/digest.md: the checked claims per slice, for the brain

Each worker is `pi --mode json -p` with the agent file's model, thinking, tools and prompt,
PI_CLAIMS_FILE (claims.ts: it can't finish without that file, and writes nothing else),
PI_TOOL_BUDGET from max_tool_calls, and PI_DELEGATE=0. Its claims go through checkrefs; a
slice with no claims file, or with no or mostly unfound quotes, is retried once with what
was missing. Standard library only.
"""
import argparse
import concurrent.futures as cf
import fcntl
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time

AGENTS_DIR = os.path.expanduser("~/.pi/agent/agents")
RUNNABLE = ("pending", "redo")
VERIFIED = ("exact", "fixed")
DROPPED = ("missing", "nofile", "short")
MAX_LINES = 800

lock = threading.Lock()
procs = set()


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
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(ledger, f, indent=1)
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
        if s["lines"][1] - s["lines"][0] + 1 > MAX_LINES:
            problems.append(f"{where}: {s['lines'][1] - s['lines'][0] + 1} lines; split it (at most {MAX_LINES})")
        s.setdefault("status", "pending")
        s.setdefault("attempts", 0)
        s.setdefault("tries", [])
        if s["status"] not in ("pending", "running", "done", "failed", "redo"):
            problems.append(f"{where}: unknown status {s['status']!r}")
    return problems


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


def brief(ledger, s, claims, last):
    a, b = s["lines"]
    qs = "\n".join(f"{i + 1}. {q}" for i, q in enumerate(s["questions"]))
    text = (
        f"Slice {s['id']} of a larger job. The job: {ledger['goal']}\n\n"
        f"Read {s['file']}, lines {a}-{b} (paths are relative to your working directory).\n"
        f"Answer:\n{qs}\n\n"
        f"Your claims file: {claims}\n"
        "Each fact is a claim with its line and a quote copied from that line. If a question "
        "isn't answered in your range, say so in open_questions, with the name of the function "
        "or file where the answer probably is."
    )
    if last:
        text += f"\n\nThis is another try at this slice. Last time: {'; '.join(last['reasons'])}."
        if last.get("unfound"):
            text += (" These quotes weren't found in the file, so those claims were thrown away; "
                     "copy quotes from the read output, or leave the claim out:\n"
                     + "\n".join(f"- {c['file']}:{c['line']} {c['quote']!r}" for c in last["unfound"][:8]))
        if last.get("kept"):
            text += f"\n{last['kept']} claims from last time were verified and are kept; you needn't repeat them."
    return text


def run_worker(ledger, s, claims, log, agent, opts, last):
    """Run one worker; returns what it did (stop reason, turns, tokens, seconds, reply)."""
    args = ["pi", "--mode", "json", "-p", "--no-session"]
    model = opts.model or agent.get("model")
    thinking = opts.thinking or agent.get("thinking")
    if model:
        args += ["--model", model]
    if thinking:
        args += ["--thinking", thinking]
    if agent.get("tools"):
        args += ["--tools", ",".join(t.strip() for t in agent["tools"].split(","))]
    env = dict(os.environ)
    for k in ("PI_RESEARCH_DIR", "PI_DELEGATE_LOG"):
        env.pop(k, None)
    env.update(PI_AGENT_NAME=f"reader-{s['id']}", PI_CLAIMS_FILE=claims, PI_DELEGATE="0")
    if agent.get("max_tool_calls"):
        env["PI_TOOL_BUDGET"] = agent["max_tool_calls"]
    timeout = float(agent.get("timeout") or 15) * 60
    info = {"model": model, "stop": None, "turns": 0, "input": 0, "output": 0, "reply": ""}
    start = time.time()
    p, timed_out = None, threading.Event()
    with tempfile.NamedTemporaryFile("w", suffix=".md", prefix="pi-orch-", delete=False) as pf:
        pf.write(agent["prompt"])
    args += ["--append-system-prompt", pf.name, f"Task: {brief(ledger, s, claims, last)}"]
    try:
        with open(log, "w", encoding="utf-8") as logf:
            p = subprocess.Popen(args, cwd=ledger["root"], env=env, stdin=subprocess.DEVNULL,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                 start_new_session=True)
            with lock:
                procs.add(p)
            timer = threading.Timer(timeout, lambda: (timed_out.set(), kill(p)))
            timer.start()
            err = []
            t = threading.Thread(target=lambda: err.extend(p.stderr), daemon=True)
            t.start()
            for line in p.stdout:
                logf.write(line)
                try:
                    ev = json.loads(line)
                except ValueError:
                    continue
                m = ev.get("message") if ev.get("type") == "message_end" else None
                if not isinstance(m, dict) or m.get("role") != "assistant":
                    continue
                info["turns"] += 1
                u = m.get("usage") or {}
                info["input"] += u.get("input") or 0
                info["output"] += u.get("output") or 0
                info["stop"] = m.get("stopReason") or info["stop"]
                if m.get("errorMessage"):
                    info["error"] = str(m["errorMessage"])[:300]
                text = "".join(c.get("text", "") for c in m.get("content") or [] if c.get("type") == "text")
                if text.strip():
                    info["reply"] = text.strip()[:500]
            p.wait()
            timer.cancel()
            t.join(5)
            if timed_out.is_set():
                info["stop"] = "timeout"
            info["exit"] = p.returncode
            if p.returncode and err:
                info["stderr"] = "".join(err)[-500:]
    finally:
        os.unlink(pf.name)
        with lock:
            procs.discard(p)
    info["seconds"] = round(time.time() - start)
    return info


def kill(p):
    try:
        os.killpg(p.pid, signal.SIGTERM)
    except OSError:
        pass


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
    for _ in range(opts.tries):
        with lock:
            s["attempts"] += 1
            n = s["attempts"]
            s["status"] = "running"
            claims = os.path.join(notes, f"{sid}.try{n}.json")
            save(path, ledger)
        a, b = s["lines"]
        say(f"{sid} try {n}: {s['file']}:{a}-{b}")
        if os.path.exists(claims):
            os.unlink(claims)
        info = run_worker(ledger, s, claims, os.path.join(notes, "logs", f"{sid}.try{n}.jsonl"), agent, opts, last)
        data, checked = check_claims(ledger, claims)
        counts = tally(checked)
        reasons = []
        if data is None:
            reasons.append(f"no valid claims file (the worker stopped: {info.get('error') or info['stop'] or 'exit ' + str(info.get('exit'))})")
        elif data.get("garbled") is True:
            reasons.append("the worker reported garbled code")
        elif not checked:
            reasons.append("no claims")
        elif counts["verified"] + counts["flagged"] == 0:
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
            garbled = data is not None and data.get("garbled") is True
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
                for p in list(procs):
                    kill(p)
                for s in ledger["slices"]:
                    if s["status"] == "running":
                        s["status"] = "pending"
                save(a.ledger, ledger)
            die("stopped; running slices are back to pending")
        pool.shutdown()
    status(ledger)
    print(f"digest: {write_digest(a.ledger, ledger)}")


def status(ledger):
    tot = {"verified": 0, "flagged": 0, "dropped": 0}
    for s in ledger["slices"]:
        c = {k: sum(t[k] for t in s.get("tries", [])) for k in tot}
        for k in tot:
            tot[k] += c[k]
        a, b = s["lines"]
        print(f"{s['id']:<8} {s.get('status', 'pending'):<8} tries {s.get('attempts', 0)}  "
              f"{c['verified']:>3} ok {c['flagged']:>2} flagged {c['dropped']:>2} dropped  {s['file']}:{a}-{b}")
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
           f"`{ledger['root']}`). `[far]`: the quote is elsewhere in the file than cited; "
           "`[numbers N]`: the claim states a number its quote doesn't show. Check those before "
           "using them. Unfound quotes are left out and only counted.", ""]
    for s in ledger["slices"]:
        a, b = s["lines"]
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
                claims.append(f"- {clip(c.get('claim', ''), 300)} — `{c.get('file')}:{c.get('line')}`{tag}"
                              f" `{clip(c.get('quote', ''), 100)}`")
        out.append(f"## {s['id']}: {s['file']}:{a}-{b} ({s.get('status', 'pending')}, "
                   f"{s.get('attempts', 0)} tries, {len(claims)} claims, {dropped} dropped)")
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
            p.add_argument("--thinking", help="worker thinking level instead of the agent file's")
            p.add_argument("--agent", default="reader", help="agent name in ~/.pi/agent/agents, or a .md path")
            p.add_argument("--only", help="comma-separated slice ids")
    a = ap.parse_args()
    a.ledger = os.path.abspath(a.ledger)
    if a.cmd == "run" and (a.jobs < 1 or a.tries < 1):
        die("--jobs and --tries must be at least 1")
    {"check": cmd_check, "run": cmd_run, "status": cmd_status, "digest": cmd_digest}[a.cmd](a)


if __name__ == "__main__":
    main()
