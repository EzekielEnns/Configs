"""pi-stats [--days N] [--sessions] [FILE_OR_DIR...]: speed, tokens and cost of Pi sessions.

Reads Pi's session files (default: ~/.pi/agent/sessions and ~/.pi/chat/sessions) and prints:
- per model: replies, input / cached / output tokens, dollars (what cost.ts recorded; local
  models are $0), seconds per step and output tokens per second (time between messages,
  steps over 15 min left out), errors and aborts;
- per kind of work: steps and tool calls per user message, compactions, and for pichat
  lookups per message, the numbers ai-stack docs/SPEED-COST-PLAN.md is judged on;
- with --sessions, one line per session.

Standard library only; reads, never writes.
"""

import argparse
import collections
import datetime as dt
import json
import os
import sys
from pathlib import Path

HOME = Path.home()
DEFAULT_DIRS = [HOME / ".pi/agent/sessions", HOME / ".pi/chat/sessions"]
LOOKERS = {"lookup", "dig"}


def ts(s):
    try:
        return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
    except (AttributeError, ValueError):
        return None


def kind(path, cwd):
    if "/.pi/chat/" in str(path):
        return "pichat"
    if "/pi-eval" in cwd or "orch" in cwd:
        return "orch"
    return "agent"


def read(path):
    s = dict(
        file=str(path), cwd="", start=None, end=None, users=0, steps=0, compact=0, abort=0, err=0,
        tools=collections.Counter(), looks_per_msg=[], models=collections.Counter(), cost=0.0, inp=0, out=0, cache=0,
    )
    per_model = collections.defaultdict(collections.Counter)
    prev = None
    looks = None
    for line in open(path, encoding="utf-8", errors="replace"):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        t = ts(d.get("timestamp", ""))
        if t:
            s["start"] = s["start"] or t
            s["end"] = t
        ty = d.get("type")
        if ty == "session":
            s["cwd"] = d.get("cwd", "")
        if ty == "compaction":
            s["compact"] += 1
        if ty != "message":
            continue
        m = d.get("message") or {}
        role = m.get("role")
        if role == "user":
            s["users"] += 1
            if looks is not None:
                s["looks_per_msg"].append(looks)
            looks = 0
        if role == "assistant":
            s["steps"] += 1
            model = f'{m.get("provider")}/{m.get("model")}'
            s["models"][model] += 1
            u = m.get("usage") or {}
            i, o, c = u.get("input") or 0, u.get("output") or 0, u.get("cacheRead") or 0
            cost = u.get("cost", {}).get("total", 0) if isinstance(u.get("cost"), dict) else 0
            s["inp"] += i
            s["out"] += o
            s["cache"] += c
            s["cost"] += cost or 0
            pm = per_model[model]
            pm["steps"] += 1
            pm["in"] += i
            pm["out"] += o
            pm["cache"] += c
            pm["micro$"] += int((cost or 0) * 1e6)
            if prev and t and 0 < t - prev < 900:
                pm["ms"] += int((t - prev) * 1000)
                pm["timed"] += 1
                pm["timed_out"] += o
            stop = m.get("stopReason")
            if stop == "aborted":
                s["abort"] += 1
                pm["aborts"] += 1
            if stop == "error" or m.get("errorMessage"):
                s["err"] += 1
                pm["errors"] += 1
            for b in m.get("content") or []:
                if isinstance(b, dict) and b.get("type") == "toolCall":
                    s["tools"][b.get("name")] += 1
                    if b.get("name") in LOOKERS and looks is not None:
                        looks += 1
        prev = t
    if looks is not None:
        s["looks_per_msg"].append(looks)
    return s, per_model


def files(args):
    roots = [Path(a).expanduser() for a in args] or DEFAULT_DIRS
    for r in roots:
        if r.is_file():
            yield r
        elif r.is_dir():
            yield from sorted(r.rglob("*.jsonl"))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--days", type=float, help="only sessions active in the last N days")
    ap.add_argument("--sessions", action="store_true", help="one line per session too")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    a = ap.parse_args()
    since = dt.datetime.now().timestamp() - a.days * 86400 if a.days else 0

    sessions, models = [], collections.defaultdict(collections.Counter)
    for f in files(a.paths):
        s, pm = read(f)
        if not s["steps"] or (s["end"] or 0) < since:
            continue
        s["kind"] = kind(f, s["cwd"])
        sessions.append(s)
        for k, v in pm.items():
            models[k].update(v)
    if not sessions:
        sys.exit("no sessions found")

    kinds = collections.defaultdict(lambda: collections.Counter())
    looks = collections.defaultdict(list)
    for s in sessions:
        k = kinds[s["kind"]]
        k["sessions"] += 1
        for f in ("users", "steps", "compact", "abort", "err"):
            k[f] += s[f]
        k["tools"] += sum(s["tools"].values())
        k["minutes"] += int(((s["end"] or 0) - (s["start"] or 0)) / 60)
        looks[s["kind"]] += [n for n in s["looks_per_msg"] if n]

    if a.json:
        json.dump({"models": models, "kinds": kinds, "sessions": sessions}, sys.stdout, default=lambda o: dict(o) if isinstance(o, collections.Counter) else str(o), indent=1)
        return

    print(f"{len(sessions)} sessions" + (f", last {a.days:g} days" if a.days else ""))
    print(f"\n{'model':34} {'steps':>6} {'in':>8} {'cached':>8} {'out':>7} {'$':>8} {'s/step':>6} {'tok/s':>6} {'err':>4} {'abort':>5}")
    for m, p in sorted(models.items(), key=lambda x: -x[1]["steps"]):
        sec = p["ms"] / 1000 / max(p["timed"], 1)
        tps = p["timed_out"] / (p["ms"] / 1000) if p["ms"] else 0
        print(f'{m[:34]:34} {p["steps"]:6} {p["in"]/1e6:7.2f}M {p["cache"]/1e6:7.2f}M {p["out"]/1e3:6.0f}k {p["micro$"]/1e6:8.2f} {sec:6.1f} {tps:6.1f} {p["errors"]:4} {p["aborts"]:5}')

    print(f"\n{'kind':8} {'sess':>5} {'msgs':>5} {'steps/msg':>9} {'tools/msg':>9} {'compact':>7} {'lookups/research msg':>22}")
    for name, k in sorted(kinds.items()):
        u = max(k["users"], 1)
        lk = looks.get(name) or []
        lstr = f"{sum(lk)/len(lk):.1f} (max {max(lk)}, n={len(lk)})" if lk else "-"
        print(f'{name:8} {k["sessions"]:5} {k["users"]:5} {k["steps"]/u:9.1f} {k["tools"]/u:9.1f} {k["compact"]:7} {lstr:>22}')

    if a.sessions:
        print(f"\n{'started':16} {'kind':6} {'cwd':30} {'msgs':>4} {'steps':>5} {'in':>7} {'out':>6} {'$':>6} {'span':>5} {'cmp':>3} top tools")
        for s in sorted(sessions, key=lambda s: s["start"] or 0):
            start = dt.datetime.fromtimestamp(s["start"] or 0).strftime("%Y-%m-%d %H:%M")
            mins = ((s["end"] or 0) - (s["start"] or 0)) / 60
            cwd = s["cwd"].replace(str(HOME), "~")[-30:]
            top = ", ".join(f"{n} {c}" for n, c in s["tools"].most_common(3))
            print(f'{start:16} {s["kind"]:6} {cwd:30} {s["users"]:4} {s["steps"]:5} {s["inp"]/1e3:6.0f}k {s["out"]/1e3:5.1f}k {s["cost"]:6.2f} {mins:5.0f} {s["compact"]:3} {top}')


if __name__ == "__main__":
    main()
