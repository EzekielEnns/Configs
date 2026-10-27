#!/usr/bin/env python3
"""Score pi-orch runs against an answer key, to compare worker models on the same job.

The job is pi-orch and three Pi extensions as of commit `snapshot` in slices.json, so the key's
line numbers don't drift as the code changes. key.json has 24 facts, each with the line it's
on, a quote from that line, and terms a claim has to state (any one of each group).

  score.py check-key          each key quote is on its line in the snapshot
  score.py prep RUN           RUN/src: the snapshot; RUN/ledger.json: the slices, ready for
                              pi-orch run RUN/ledger.json [--model M]
  score.py score RUN...       one column per run [--price MODEL=IN/OUT per 1M tokens]

A key fact is `located` when a claim whose quote checkrefs found (exact, fixed or far) is at
its line (±2, or the fact's span), and `found` when that claim also states the terms. Claims
are counted by checkrefs status; `numbers` is claims stating a number their quote doesn't.
Cost uses PRICES (US hosts, per 1M in/out); Flint is local, so 0. Wall time runs from the
first worker's start to the last one's end. Standard library only.
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
PRICES = {"desktop/flint": (0, 0), "desktop/flint-careful": (0, 0), "desktop/cloud-gptoss": (0.037, 0.17)}
FOUND = ("exact", "fixed", "far")
STATUSES = ("exact", "fixed", "far", "missing", "nofile", "short")


def load(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
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
    with tempfile.TemporaryFile() as t:
        subprocess.run(["git", "-C", REPO, "archive", plan["snapshot"], *plan["paths"]], stdout=t, check=True)
        t.seek(0)
        with tarfile.open(fileobj=t) as tar:
            tar.extractall(src, filter="data")
    ledger = {"goal": plan["goal"], "root": plan["root"],
              "slices": [{k: s[k] for k in ("id", "file", "lines", "questions")} for s in plan["slices"]]}
    with open(os.path.join(a.run, "ledger.json"), "w", encoding="utf-8") as f:
        json.dump(ledger, f, indent=1)
        f.write("\n")
    print(f"pi-orch run {os.path.join(a.run, 'ledger.json')}   # add --model desktop/cloud-gptoss for the hosted worker")


def says(text, term):
    # Numbers and names as whole words: "4" mustn't match "40" or "0.4".
    return re.search(rf"(?<![\w.]){re.escape(term)}(?![\w])" if term[0].isalnum() else re.escape(term), text, re.I)


def score(run, key, prices):
    with open(os.path.join(run, "ledger.json"), encoding="utf-8") as f:
        ledger = json.load(f)
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
        here = [c for c in claims if c.get("status") in FOUND and str(c.get("file", "")).lstrip("./") == k["file"]
                and k["line"] + lo <= int(c.get("line") or 0) <= k["line"] + hi]
        hit = [c for c in here if all(any(says(str(c.get("claim", "")), t) for t in g) for g in k["terms"])]
        facts[k["id"]] = "found" if hit else "located" if here else "missed"
    counts = {st: sum(c.get("status") == st for c in claims) for st in STATUSES}
    tin, tout = sum(t.get("input", 0) for t in tries), sum(t.get("output", 0) for t in tries)
    cost = 0.0
    for t in tries:
        p = prices.get(t.get("model"))
        if p is None:
            cost = None
            break
        cost += (t.get("input", 0) * p[0] + t.get("output", 0) * p[1]) / 1e6
    spans = []
    for t, log in ((t, os.path.join(run, "logs", t["claims"][:-5] + ".jsonl")) for t in tries):
        if os.path.exists(log):
            end = os.path.getmtime(log)
            spans.append((end - t.get("seconds", 0), end))
    return {
        "model": ", ".join(sorted(models)) or "(not run)",
        "slices": f"{sum(s.get('status') == 'done' for s in ledger['slices'])}/{len(ledger['slices'])} done",
        "tries": len(tries),
        "found": sum(v == "found" for v in facts.values()),
        "located": sum(v != "missed" for v in facts.values()),
        "claims": len(claims), **counts,
        "numbers": sum(bool(c.get("numbers")) for c in claims),
        "tokens in/out": f"{tin / 1000:.0f}k/{tout / 1000:.0f}k",
        "cost": "?" if cost is None else f"${cost:.4f}",
        "worker time": f"{sum(t.get('seconds', 0) for t in tries) / 60:.1f}m",
        "wall": f"{(max(e for _, e in spans) - min(s for s, _ in spans)) / 60:.1f}m" if spans else "-",
        "facts": facts,
    }


def cmd_score(a):
    key = load("key.json")
    prices = dict(PRICES)
    for p in a.price:
        m, _, v = p.partition("=")
        i, _, o = v.partition("/")
        prices[m] = (float(i), float(o))
    runs = [score(r, key, prices) for r in a.runs]
    n = len(key)
    rows = [("run", [os.path.basename(os.path.normpath(r)) for r in a.runs])]
    rows += [(k, [str(r[k]) for r in runs]) for k in ("model", "slices", "tries")]
    rows += [("found", [f"{r['found']}/{n} ({r['found'] / n:.0%})" for r in runs]),
             ("located", [f"{r['located']}/{n}" for r in runs])]
    rows += [(k, [str(r[k]) for r in runs]) for k in ("claims", *STATUSES, "numbers", "tokens in/out", "cost", "worker time", "wall")]
    w = max(len(k) for k, _ in rows) + 2
    cw = max(14, *(len(v) + 2 for _, vs in rows for v in vs))
    for k, vs in rows:
        print(k.ljust(w) + "".join(v.ljust(cw) for v in vs).rstrip())
    print("\nfacts (+ found, ~ located but the claim doesn't state it, . missed):")
    mark = {"found": "+", "located": "~", "missed": "."}
    for k in key:
        print(f"  {' '.join(mark[r['facts'][k['id']]] for r in runs)}  {k['id']:<4} {k['slice']} {k['file']}:{k['line']}  {k['fact']}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("check-key")
    sub.add_parser("prep").add_argument("run")
    p = sub.add_parser("score")
    p.add_argument("runs", nargs="+")
    p.add_argument("--price", action="append", default=[], help="MODEL=IN/OUT dollars per 1M tokens")
    a = ap.parse_args()
    {"check-key": cmd_check_key, "prep": cmd_prep, "score": cmd_score}[a.cmd](a)


if __name__ == "__main__":
    main()
