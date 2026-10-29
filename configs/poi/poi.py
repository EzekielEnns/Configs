"""poi: points of interest. Jev ranks code, diff hunks or web passages against a question and
prints a jump list, best first.

  poi "question" [PATH|URL ...]       rank blocks of files under PATHs (default .) or page text
  poi --diff [REF|RANGE] ["focus"]    rank diff hunks: working tree vs HEAD, vs REF, or A...B

  -n N      show the top N (default 20)      --all    show everything
  --json    machine-readable output          --yes    go past the block cap
  --cap N   blocks before asking for --yes (default 500)

Jev (a decision model on OpenRouter, through the desktop gateway, which adds the key) scores each
block 0-3 on how much it bears on the question, plus its yes-probability that the block answers
part of it; the rank is the sum, 0-4. Files that look like secrets are never sent.
Standard library only.
"""
import argparse, concurrent.futures as cf, html, json, os, re, subprocess, sys, time, urllib.parse, urllib.request

JEV_URL = os.environ.get("POI_JEV_URL", "http://desktop:4000/openrouter/decisions")
JEV_MODEL = os.environ.get("POI_JEV_MODEL", "typesafe/jev-1.14")
LEVELS = [
    "Nothing here bears on the question.",
    "Background only: helps understand it, but answers no part of the question.",
    "Relevant: part of what the question asks about.",
    "Directly answers part of the question.",
]
DIFF_FOCUS = "risky, surprising or behavior-changing changes worth a careful review"
BLOCK = 12          # lines per code block
PARA_MAX = 15       # lines per text paragraph block
MAX_FILE = 400_000  # bytes: bigger files are generated or data
MAX_PAGE = 2_000_000
SECRET = re.compile(r"(^|/)(\.env[^/]*|[^/]*\.pem|[^/]*key[^/]*|auth\.json|secrets?[^/]*|id_(rsa|ed25519|ecdsa)[^/]*|"
                    r"[^/]*\.(p12|pfx|keystore|kdbx))$", re.I)
SKIP = re.compile(r"(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|flake\.lock|poetry\.lock|"
                  r"go\.sum|[^/]*\.min\.(js|css)|[^/]*\.map)$|\.(png|jpe?g|gif|ico|pdf|zip|gz|tar|wasm|so|dylib|"
                  r"o|a|bin|exe|parquet|ttf|woff2?|mp[34]|mov|db|sqlite)$", re.I)
TEXT = re.compile(r"\.(md|txt|rst|adoc|org)$", re.I)


def files_under(path):
    if os.path.isfile(path):
        return [path]
    p = subprocess.run(["git", "-C", path, "ls-files", "-co", "--exclude-standard"], capture_output=True, text=True)
    if p.returncode == 0:
        return [os.path.join(path, f) for f in p.stdout.splitlines()]
    p = subprocess.run(["rg", "--files", path], capture_output=True, text=True)
    if p.returncode in (0, 1):
        return p.stdout.splitlines()
    return [os.path.join(d, f) for d, _, fs in os.walk(path) for f in fs]


def read_text(path):
    try:
        if os.path.getsize(path) > MAX_FILE:
            return None
        data = open(path, "rb").read()
    except OSError:
        return None
    if b"\0" in data[:8192]:
        return None
    s = data.decode("utf-8", "replace")
    if any(len(line) > 2000 for line in s.splitlines()[:50]):
        return None  # minified
    return s


def terms(question):
    return {w for w in re.findall(r"[a-z0-9]{3,}", question.lower())} - {"the", "and", "how", "what", "where", "which",
                                                                           "does", "with", "for", "are", "this", "that"}


def best_line(lines, a, b, words):
    """The line to jump to: the one sharing the most words (or word stems) with the question, else the first
    non-blank one."""
    def hits(line):
        low = line.lower()
        return sum(w[:5] in low for w in words)
    span = [n for n in range(a, b + 1) if lines[n - 1].strip()]
    best = max(span, key=lambda n: (hits(lines[n - 1]), -n))
    return best if hits(lines[best - 1]) else span[0]


def text_blocks(lines):
    """Paragraphs (split on blank lines), long ones cut at PARA_MAX: [(first line, last line)]."""
    out, start = [], None
    for i, line in enumerate(lines + [""], 1):
        if line.strip() and start is None:
            start = i
        if (not line.strip() or (start and i - start + 1 >= PARA_MAX)) and start is not None:
            end = i - 1 if not line.strip() else i
            out.append((start, end))
            start = None
    return out


def code_blocks(lines):
    """BLOCK-line windows, skipping all-blank ones."""
    out = []
    for a in range(1, len(lines) + 1, BLOCK):
        b = min(a + BLOCK - 1, len(lines))
        if any(lines[n - 1].strip() for n in range(a, b + 1)):
            out.append((a, b))
    return out


def file_items(paths, skipped, question):
    items, words = [], terms(question)
    for root in paths:
        for f in files_under(root):
            rel = os.path.relpath(f)
            if SECRET.search(rel):
                skipped.append(rel)
                continue
            if SKIP.search(rel):
                continue
            s = read_text(f)
            if not s:
                continue
            lines = s.splitlines()
            for a, b in (text_blocks if TEXT.search(rel) else code_blocks)(lines):
                body = "\n".join(f"{n}\t{lines[n - 1]}" for n in range(a, b + 1))
                n = best_line(lines, a, b, words)
                items.append({"where": f"{rel}:{n}", "label": f"Lines {a}-{b} of {rel} (number, tab, text)",
                              "text": body, "preview": lines[n - 1].strip()})
    return items


class Text(__import__("html.parser").parser.HTMLParser):
    BLOCKS = {"p", "div", "li", "pre", "tr", "h1", "h2", "h3", "h4", "h5", "h6", "section", "article", "br",
              "blockquote", "dd", "dt", "table"}

    def __init__(self):
        super().__init__()
        self.out, self.skip = [], 0

    def handle_starttag(self, tag, _):
        if tag in ("script", "style", "noscript", "svg", "nav", "header", "footer"):
            self.skip += 1
        if tag in self.BLOCKS:
            self.out.append("\n\n" if tag != "br" else "\n")

    def handle_endtag(self, tag):
        if tag in ("script", "style", "noscript", "svg", "nav", "header", "footer"):
            self.skip = max(0, self.skip - 1)
        if tag in self.BLOCKS:
            self.out.append("\n\n")

    def handle_data(self, d):
        if not self.skip:
            self.out.append(d)


def url_items(url, words):
    req = urllib.request.Request(url, headers={"User-Agent": "poi/1"})
    with urllib.request.urlopen(req, timeout=30) as r:
        raw = r.read(MAX_PAGE).decode(r.headers.get_content_charset() or "utf-8", "replace")
        ctype = r.headers.get_content_type()
    if "html" in ctype:
        t = Text()
        t.feed(raw)
        raw = html.unescape("".join(t.out))
    paras = [re.sub(r"[ \t]+", " ", p).strip() for p in re.split(r"\n\s*\n", raw)]
    paras = [p for p in paras if len(p) > 40]
    items, buf = [], ""
    for p in paras:  # merge short paragraphs up to ~1200 chars a passage
        if buf and len(buf) + len(p) > 1200:
            items.append(buf)
            buf = ""
        buf = (buf + "\n" + p).strip()
    if buf:
        items.append(buf)
    out = []
    for i, p in enumerate(items, 1):
        lines = p.splitlines()
        line = lines[best_line(lines, 1, len(lines), words) - 1].strip()
        frag = "#:~:text=" + urllib.parse.quote(" ".join(line.split()[:6]), safe="")
        out.append({"where": f"passage {i}", "link": f"{url.split('#')[0]}{frag}", "label": f"Passage {i} of {url}",
                    "text": p, "preview": line})
    return out


def diff_items(ref):
    args = ["git", "diff", "--no-color", "-U3"] + ([ref] if ref else ["HEAD"])
    p = subprocess.run(args, capture_output=True, text=True)
    if p.returncode:
        sys.exit(f"poi: {' '.join(args)} failed: {p.stderr.strip()}")
    items, skipped, path, hunk = [], [], None, None

    def flush():
        if hunk and path and not SECRET.search(path) and not SKIP.search(path):
            body = "\n".join(hunk["lines"])
            items.append({"where": f"{path}:{hunk['line']}", "label": f"Diff hunk in {path} at line {hunk['line']}",
                          "text": body[:6000], "preview": hunk["preview"]})
        elif hunk and path and SECRET.search(path):
            skipped.append(path)

    for line in p.stdout.splitlines():
        if line.startswith("diff --git"):
            flush()
            hunk, path = None, None
        elif line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else path
        elif line.startswith("--- a/") and path is None:
            path = line[6:]
        elif line.startswith("@@"):
            flush()
            m = re.search(r"\+(\d+)", line)
            hunk = {"line": int(m.group(1)) if m else 1, "lines": [line], "preview": ""}
        elif hunk is not None:
            hunk["lines"].append(line)
            if not hunk["preview"] and line[:1] in "+-" and line[1:].strip():
                hunk["preview"] = line.strip()
    flush()
    return items, sorted(set(skipped))


def ask(question, item):
    body = {"model": JEV_MODEL, "state": [f"Question: {question}", f"{item['label']}:\n{item['text']}"],
            "questions": {"rel": {"type": "score", "instructions": "How much does this bear on the question?",
                                  "criteria": LEVELS},
                          "part": {"type": "noul", "instructions": f"This answers part of this question: {question}"}}}
    req = urllib.request.Request(JEV_URL, json.dumps(body).encode(), {"Content-Type": "application/json"})
    for attempt in range(2):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)
            a = d["answers"]
            return float(a["rel"]["score"]) + float(a["part"]["noul"]), float(d.get("usage", {}).get("cost", 0))
        except Exception:  # noqa: BLE001 - one retry, then the caller reports it
            if attempt:
                raise
            time.sleep(1)


def main():
    ap = argparse.ArgumentParser(prog="poi", usage=argparse.SUPPRESS, description=__doc__.rsplit("Standard", 1)[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter, add_help=False)
    ap.add_argument("-h", "--help", action="help", help=argparse.SUPPRESS)
    ap.add_argument("args", nargs="*", help=argparse.SUPPRESS)
    ap.add_argument("--diff", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("-n", type=int, default=20, help=argparse.SUPPRESS)
    ap.add_argument("--all", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--yes", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--cap", type=int, default=500, help=argparse.SUPPRESS)
    o = ap.parse_args()

    skipped = []
    if o.diff:
        # poi --diff [REF|RANGE] ["focus"]: a first arg git knows is the ref.
        ref, rest = None, o.args
        if rest and subprocess.run(["git", "rev-parse", "-q", "--verify", rest[0].split("...")[-1].split("..")[-1] or "HEAD"],
                                   capture_output=True).returncode == 0:
            ref, rest = rest[0], rest[1:]
        question = " ".join(rest) or DIFF_FOCUS
        items, skipped = diff_items(ref)
    else:
        if not o.args:
            ap.error("give a question")
        question, targets = o.args[0], o.args[1:] or ["."]
        items = []
        local = [t for t in targets if not re.match(r"https?://", t)]
        for t in targets:
            if re.match(r"https?://", t):
                try:
                    items += url_items(t, terms(question))
                except Exception as e:  # noqa: BLE001
                    print(f"poi: couldn't fetch {t}: {e}", file=sys.stderr)
        if local:
            items += file_items(local, skipped, question)

    for s in skipped:
        print(f"poi: skipped (looks like a secret): {s}", file=sys.stderr)
    if not items:
        sys.exit("poi: nothing to rank")
    est = len(items) * 0.000016
    if len(items) > o.cap and not o.yes:
        sys.exit(f"poi: {len(items)} blocks (about ${est:.3f} and {len(items) // 8 + 1}s); narrow the paths or add --yes")
    print(f"poi: ranking {len(items)} blocks with Jev...", file=sys.stderr)

    start, cost, failed = time.time(), 0.0, 0
    with cf.ThreadPoolExecutor(8) as ex:
        futs = {ex.submit(ask, question, it): it for it in items}
        for f in cf.as_completed(futs):
            try:
                futs[f]["rank"], c = f.result()
                cost += c
            except Exception:  # noqa: BLE001
                futs[f]["rank"] = None
                failed += 1
    if failed == len(items):
        sys.exit(f"poi: Jev unreachable at {JEV_URL} (is the desktop gateway up?)")
    ranked = sorted((it for it in items if it["rank"] is not None), key=lambda it: -it["rank"])
    shown = ranked if o.all else ranked[:o.n]
    if o.json:
        print(json.dumps([{"where": it["where"], "rank": round(it["rank"], 2), "preview": it["preview"],
                           **({"link": it["link"]} if "link" in it else {})} for it in shown], indent=1))
    else:
        w = max(len(it["where"]) for it in shown)
        for it in shown:
            print(f"{it['where']:<{w}}  {it['rank']:.2f}  {it['preview'][:100]}")
            if "link" in it:
                print(f"{'':<{w}}        {it['link']}")
    note = f", {failed} failed" if failed else ""
    print(f"poi: {len(items)} blocks in {time.time() - start:.0f}s, ${cost:.4f}{note}", file=sys.stderr)


if __name__ == "__main__":
    main()
