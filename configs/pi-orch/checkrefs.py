#!/usr/bin/env python3
"""Check workers' claims against the files they cite.

A claim is {"claim", "file", "line", "quote"}: `quote` is text copied from that line. For each
claim, look for the quote at the cited line, then nearby, then anywhere in the file:
  exact    the quote is on the cited line
  fixed    found within --near lines; the line number is corrected
  far      found elsewhere in the file; the line is corrected, but the claim may be about
           another spot, so it's worth a look
  missing  the quote isn't in the file: made up or mis-copied (e.g. hex converted)
  nofile   the cited file doesn't exist
Matching ignores whitespace differences; quotes under 6 characters can't be checked (short).
A found claim whose text has a number the quote doesn't (as decimal or hex) also gets
`numbers`: small models convert hex constants wrongly (0x780 written up as 640).

  checkrefs.py [--root DIR] [--near N] [--write] CLAIMS.json...
Prints a summary per file; --write saves CLAIMS.checked.json next to each input with a
`status` on every claim and corrected `line`s. Standard library only.
"""
import argparse
import json
import os
import re
import sys

ws = re.compile(r"\s+")
num = re.compile(r"\b(?:0x[0-9a-fA-F]+|\d+(?:\.\d+)?)\b")


def values(text):
    out = set()
    for n in num.findall(text):
        try:
            out.add(int(n, 16) if n.lower().startswith("0x") else float(n))
        except ValueError:
            pass
    return out


def norm(s):
    return ws.sub(" ", s).strip()


def load_lines(path, cache):
    if path not in cache:
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                cache[path] = [norm(l) for l in f]
        except OSError:
            cache[path] = None
    return cache[path]


def check(claim, root, near, cache):
    out = dict(claim)
    quote = norm(str(claim.get("quote") or ""))
    path = os.path.join(root, str(claim.get("file") or ""))
    lines = load_lines(path, cache)
    if lines is None:
        out["status"] = "nofile"
        return out
    if len(quote) < 6:
        out["status"] = "short"
        return out
    try:
        line = int(claim.get("line") or 0)
    except (TypeError, ValueError):
        line = 0
    hits = [i + 1 for i, l in enumerate(lines) if quote in l]
    if not hits:
        out["status"] = "missing"
        return out
    best = min(hits, key=lambda h: abs(h - line))
    # Numbers the claim states that the quote doesn't contain (ignoring small ones and the line number).
    unsupported = sorted(n for n in values(str(claim.get("claim") or "")) - values(quote) if n > 9 and n != best)
    if unsupported:
        out["numbers"] = [int(n) if n == int(n) else n for n in unsupported]
    out["status"] = "exact" if best == line else "fixed" if abs(best - line) <= near else "far"
    if best != line:
        out["cited_line"] = line
        out["line"] = best
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("claims", nargs="+")
    ap.add_argument("--root", default=".", help="folder the claims' file paths are relative to")
    ap.add_argument("--near", type=int, default=100)
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()
    cache = {}
    bad = 0
    for cf in a.claims:
        try:
            with open(cf, encoding="utf-8") as f:
                claims = json.load(f)
            if isinstance(claims, dict):
                claims = claims.get("claims", [])
        except (OSError, ValueError) as e:
            print(f"{cf}: unreadable ({e})")
            bad += 1
            continue
        checked = [check(c, a.root, a.near, cache) for c in claims if isinstance(c, dict)]
        counts = {}
        for c in checked:
            counts[c["status"]] = counts.get(c["status"], 0) + 1
            if c.get("numbers"):
                counts["numbers"] = counts.get("numbers", 0) + 1
        print(f"{cf}: {len(checked)} claims, " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))
        for c in checked:
            if c["status"] in ("missing", "nofile", "far"):
                print(f"  {c['status']}: {c.get('file')}:{c.get('cited_line', c.get('line'))} {str(c.get('quote'))[:80]!r}")
            if c.get("numbers"):
                print(f"  numbers not in the quote {c['numbers']}: {c.get('file')}:{c.get('line')} {str(c.get('claim'))[:80]!r}")
        if a.write:
            base = cf[:-5] if cf.endswith(".json") else cf
            with open(base + ".checked.json", "w", encoding="utf-8") as f:
                json.dump(checked, f, indent=1)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
