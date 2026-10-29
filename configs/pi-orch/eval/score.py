#!/usr/bin/env python3
"""Score pi-orch runs against an answer key, to compare worker models on the same job.

The job is pi-orch and three Pi extensions as of commit `snapshot` in slices.json, so the key's
line numbers don't drift as the code changes. key.json has 24 facts, each with the line it's
on, a quote from that line, and terms a claim has to state (any one of each group).

  score.py check-key          each key quote is on its line in the snapshot
  score.py prep RUN           RUN/src: the snapshot; RUN/ledger.json: the fixed slices, to
                              test workers alone: pi-orch run RUN/ledger.json [--model M]
  score.py prep --brain RUN   RUN/src only; prints the /orchestrate command that gives a brain
                              the task, with RUN as its notes folder (it writes the ledger)
  score.py score RUN...       one column per run [--price MODEL=IN/OUT per 1M tokens]

Each command takes --task NAME for another question on the same kind of snapshot: its
slices.json and key.json are in tasks/NAME/ (default: the files here, the limits question).
prep writes the name to RUN/task, and score uses the first run's.

A key fact is `located` when a claim whose quote checkrefs found (exact, fixed or far) is at
its line (±2, or the fact's span), and `found` when that claim also states the terms. A
brain's RUN/report.md is scored the same way, per point (a bullet with its wrapped lines): a
citation of the fact's file:line (or a range over it, or ":line" after a heading or citation
names the file), and the terms in that point. Claims
are counted by checkrefs status; `numbers` is claims stating a number their quote doesn't.
Cost uses PRICES (US hosts, per 1M in/out); Flint is local, so 0. Wall time runs from the
first worker's start to the last one's end. The brain's tokens come from its Pi session
files (the folder for RUN/src/configs, so use a fresh RUN per run). Standard library only.
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys
import tarfile
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
# In, out, cache read; the low end of each model's US hosts on OpenRouter (2026-10-27).
PRICES = {"desktop/flint": (0, 0, 0), "desktop/flint-careful": (0, 0, 0), "desktop/cloud-gptoss": (0.037, 0.17, 0.037),
          "desktop/cloud-deepseek": (0.112, 0.336, 0.003), "desktop/planner": (0.562, 2.50, 0.125)}
FOUND = ("exact", "fixed", "far")
STATUSES = ("exact", "fixed", "far", "missing", "nofile", "short")


TASK = None  # --task: tasks/<name>/ instead of the files here


def load(name):
    with open(os.path.join(HERE, "tasks", TASK, name) if TASK else os.path.join(HERE, name), encoding="utf-8") as f:
        return json.load(f)


def cmd_check_key(a):
    plan, bad = load("slices.json"), 0
    for k in load("key.json"):
        path = f"{plan['snapshot']}:configs/{k['file']}"
        lines = subprocess.run(["git", "-C", REPO, "show", path], capture_output=True, text=True, check=True).stdout.splitlines()
        hits = [i + 1 for i, l in enumerate(lines) if k["quote"] in l]
        if hits != [k["line"]]:
            print(f"{k['id']}: quote at {hits or 'nowhere'}, key says {k['line']}")
            bad += 1
    print(f"{bad} problems" if bad else "ok: every quote is on its line, once")
    sys.exit(1 if bad else 0)


def cmd_prep(a):
    plan = load("slices.json")
    if os.path.exists(a.run) and os.listdir(a.run):
        sys.exit(f"{a.run} isn't empty")
    src = os.path.join(a.run, "src")
    os.makedirs(src)
    if TASK:
        with open(os.path.join(a.run, "task"), "w", encoding="utf-8") as f:
            f.write(TASK + "\n")
    with tempfile.TemporaryFile() as t:
        subprocess.run(["git", "-C", REPO, "archive", plan["snapshot"], *plan["paths"]], stdout=t, check=True)
        t.seek(0)
        with tarfile.open(fileobj=t) as tar:
            tar.extractall(src, filter="data")
    if a.brain:
        cwd = os.path.abspath(os.path.join(a.run, plan["root"]))
        print(f'cd {cwd} && pi --model desktop/cloud-deepseek --thinking off "/orchestrate {plan["task"]} '
              f'Notes folder: {os.path.abspath(a.run)}. Go ahead without waiting for my ok."')
        return
    ledger = {"goal": plan["goal"], "root": plan["root"],
              "slices": [{k: s[k] for k in ("id", "file", "lines", "questions")} for s in plan["slices"]]}
    with open(os.path.join(a.run, "ledger.json"), "w", encoding="utf-8") as f:
        json.dump(ledger, f, indent=1)
        f.write("\n")
    print(f"pi-orch run {os.path.join(a.run, 'ledger.json')}   # add --model desktop/cloud-gptoss for the hosted worker")


def says(text, term):
    # Numbers and names as whole words: "4" mustn't match "40" or "0.4".
    return re.search(rf"(?<![\w.]){re.escape(term)}(?![\w])" if term[0].isalnum() else re.escape(term), text, re.I)


def items(text):
    """A report's points: each bullet or numbered item with its wrapped lines, or a paragraph."""
    out = []
    for line in text.splitlines():
        if re.match(r"\s*([-*+]|\d+[.)])\s", line) or line.startswith("#") or not out or not out[-1].strip():
            out.append(line)
        elif line.strip():
            out[-1] += " " + line.strip()
        else:
            out.append("")
    # Shorthand: after a heading or citation names a file, "`:334`" means that file's line 334.
    # Left to right, so a file named earlier in the same point counts too.
    token = re.compile(r"([\w.-]+\.(?:py|ts|rs|go|js|md|nix))(?=\W)|(?<![\w.])(?=:\d)")
    current, points = "", []
    for p in out:
        if not p.strip():
            continue

        def sub(m):
            nonlocal current
            if m.group(1):
                current = m.group(1)
                return m.group(1)
            return current

        points.append(token.sub(sub, p))
    return points


def cites(line, k):
    # file.py:42, file.py:40-45, file.py lines 40-45; the file's base name is enough.
    base = re.escape(os.path.basename(k["file"]))
    lo, hi = k.get("span", [-2, 2])
    for m in re.finditer(rf"{base}\W{{1,3}}(?:lines?\s*)?(\d+)(?:\s*[-–]\s*(\d+))?", line):
        a = int(m.group(1))
        b = int(m.group(2) or a)
        if a <= k["line"] + hi and b >= k["line"] + lo and b - a <= 40:
            return True
    return False


def brain_usage(run):
    """(model, input, cache read, output) summed over the brain's Pi sessions for this run."""
    cwd = os.path.abspath(os.path.join(run, "src", "configs"))
    d = os.path.expanduser(os.path.join("~/.pi/agent/sessions", "--" + cwd.strip("/").replace("/", "-") + "--"))
    models, tin, tcache, tout = set(), 0, 0, 0
    for path in glob.glob(os.path.join(d, "*.jsonl")):
        with open(path, encoding="utf-8") as f:
            for line in f:
                try:
                    m = json.loads(line).get("message") or {}
                except ValueError:
                    continue
                u = m.get("usage") if m.get("role") == "assistant" else None
                if u:
                    models.add(f"{m.get('provider', 'desktop')}/{m.get('model')}" if "/" not in str(m.get("model")) else m["model"])
                    tin += u.get("input") or 0
                    tcache += u.get("cacheRead") or 0
                    tout += u.get("output") or 0
    return ", ".join(sorted(models)), tin, tcache, tout


def score(run, key, prices):
    try:
        with open(os.path.join(run, "ledger.json"), encoding="utf-8") as f:
            ledger = json.load(f)
    except OSError:
        ledger = {"slices": []}  # the brain stopped before planning
    try:
        with open(os.path.join(run, "report.md"), encoding="utf-8") as f:
            report = items(f.read())
    except OSError:
        report = None
    claims, tries, models = [], [], set()
    for s in ledger["slices"]:
        for t in s.get("tries", []):
            tries.append(t)
            models.add(t.get("model") or "?")
            try:
                with open(os.path.join(run, t["claims"][:-5] + ".checked.json"), encoding="utf-8") as f:
                    claims += [c for c in json.load(f) if isinstance(c, dict)]
            except (OSError, ValueError):
                pass
    facts = {}
    for k in key:
        lo, hi = k.get("span", [-2, 2])
        here = [c for c in claims if c.get("status") in FOUND and ("/" + str(c.get("file", "")).lstrip("./")).endswith("/" + k["file"])
                and k["line"] + lo <= int(c.get("line") or 0) <= k["line"] + hi]
        hit = [c for c in here if all(any(says(str(c.get("claim", "")), t) for t in g) for g in k["terms"])]
        facts[k["id"]] = "found" if hit else "located" if here else "missed"
        if report is not None:
            lines = [l for l in report if cites(l, k)]
            ok = [l for l in lines if all(any(says(l, t) for t in g) for g in k["terms"])]
            facts["r" + k["id"]] = "found" if ok else "located" if lines else "missed"
    counts = {st: sum(c.get("status") == st for c in claims) for st in STATUSES}
    tin, tout = sum(t.get("input", 0) for t in tries), sum(t.get("output", 0) for t in tries)
    cost = 0.0
    for t in tries:
        p = prices.get(t.get("model"))
        if p is None:
            cost = None
            break
        cost += (t.get("input", 0) * p[0] + t.get("output", 0) * p[1]) / 1e6
    bmodel, bin_, bcache, bout = brain_usage(run)
    bp = prices.get(bmodel)
    bcost = None if bp is None else (bin_ * bp[0] + bout * bp[1] + bcache * bp[2]) / 1e6
    spans = []
    for t, log in ((t, os.path.join(run, "logs", t["claims"][:-5] + ".jsonl")) for t in tries):
        if os.path.exists(log):
            end = os.path.getmtime(log)
            spans.append((end - t.get("seconds", 0), end))
    return {
        "model": ", ".join(sorted(models)) or "(not run)",
        "slices": f"{sum(s.get('status') == 'done' for s in ledger['slices'])}/{len(ledger['slices'])} done",
        "tries": len(tries),
        "found": sum(facts[k["id"]] == "found" for k in key),
        "located": sum(facts[k["id"]] != "missed" for k in key),
        "report found": "-" if report is None else sum(v == "found" for k, v in facts.items() if k[0] == "r"),
        "report located": "-" if report is None else sum(v != "missed" for k, v in facts.items() if k[0] == "r"),
        "brain": f"{bmodel} {(bin_ + bcache) / 1000:.0f}k/{bout / 1000:.0f}k" if bmodel else "-",
        "brain cost": "-" if not bmodel else "?" if bcost is None else f"${bcost:.4f}",
        "claims": len(claims), **counts,
        "numbers": sum(bool(c.get("numbers")) for c in claims),
        "tokens in/out": f"{tin / 1000:.0f}k/{tout / 1000:.0f}k",
        "worker cost": "?" if cost is None else f"${cost:.4f}",
        "worker time": f"{sum(t.get('seconds', 0) for t in tries) / 60:.1f}m",
        "wall": f"{(max(e for _, e in spans) - min(s for s, _ in spans)) / 60:.1f}m" if spans else "-",
        "facts": facts,
    }


def cmd_score(a):
    global TASK
    if TASK is None and os.path.exists(os.path.join(a.runs[0], "task")):
        with open(os.path.join(a.runs[0], "task"), encoding="utf-8") as f:
            TASK = f.read().strip()
    key = load("key.json")
    prices = dict(PRICES)
    for p in a.price:
        m, _, v = p.partition("=")
        i, _, o = v.partition("/")
        prices[m] = (float(i), float(o), float(i))
    runs = [score(r, key, prices) for r in a.runs]
    n = len(key)
    rows = [("run", [os.path.basename(os.path.normpath(r)) for r in a.runs])]
    rows += [(k, [str(r[k]) for r in runs]) for k in ("brain", "model", "slices", "tries")]
    rows += [("report found", [f"{r['report found']}/{n}" if r["report found"] != "-" else "-" for r in runs]),
             ("report located", [f"{r['report located']}/{n}" if r["report located"] != "-" else "-" for r in runs]),
             ("claims found", [f"{r['found']}/{n} ({r['found'] / n:.0%})" for r in runs]),
             ("claims located", [f"{r['located']}/{n}" for r in runs])]
    rows += [(k, [str(r[k]) for r in runs]) for k in ("claims", *STATUSES, "numbers", "tokens in/out", "worker cost",
                                                       "brain cost", "worker time", "wall")]
    w = max(len(k) for k, _ in rows) + 2
    cw = max(14, *(len(v) + 2 for _, vs in rows for v in vs))
    for k, vs in rows:
        print(k.ljust(w) + "".join(v.ljust(cw) for v in vs).rstrip())
    print("\nfacts, claims then report per run (+ found, ~ located but not stated, . missed, - no report):")
    mark = {"found": "+", "located": "~", "missed": ".", None: "-"}
    for k in key:
        cols = " ".join(mark[r["facts"][k["id"]]] + mark[r["facts"].get("r" + k["id"])] for r in runs)
        print(f"  {cols}  {k['id']:<4} {k['slice']} {k['file']}:{k['line']}  {k['fact']}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("check-key")
    p = sub.add_parser("prep")
    p.add_argument("run")
    p.add_argument("--brain", action="store_true")
    p = sub.add_parser("score")
    p.add_argument("runs", nargs="+")
    p.add_argument("--price", action="append", default=[], help="MODEL=IN/OUT dollars per 1M tokens")
    for p in sub.choices.values():
        p.add_argument("--task", help="question in tasks/NAME/ (default: the limits question here)")
    a = ap.parse_args()
    global TASK
    TASK = a.task
    {"check-key": cmd_check_key, "prep": cmd_prep, "score": cmd_score}[a.cmd](a)


if __name__ == "__main__":
    main()
