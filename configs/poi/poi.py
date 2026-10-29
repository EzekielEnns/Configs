"""poi: points of interest. Jev ranks code, diff hunks or web passages against a question and
prints a jump list, best first, grouped by file.

  poi "question" [PATH|URL ...]       rank code and docs under PATHs (default .) or page text
  poi --diff [REF|RANGE] ["focus"]    rank diff hunks: working tree vs HEAD, vs REF, or A...B

  -n N        show the top N places (default 15)     --all     show everything
  --files K   rank files first, then dig into the top K (default 20)
  --flat      skip the file stage: rank every block
  --follow    under each of the top 5 hits, its callers and references (language server, else rg)
  --tour      a local model turns the hits into a short guided read (--tour-model, default flint)
  --qf        Vim quickfix lines on stdout:  nvim -q <(poi --qf "question")   (Neovim can't read -q -)
  --json      machine-readable output        --yes     go past the cost cap
  --cap N     Jev requests before asking for --yes (default 600)

Code is cut with tree-sitter (headless Neovim, poi's own parsers): a block is a whole function,
class, method or Nix binding, long ones split at statement boundaries, with the code between them
in blocks of its own. Each block goes to Jev with its path, its enclosing symbols and the file's
imports. Files without a parser fall back to 12-line windows, Markdown and text to paragraphs.

Jev (a decision model on OpenRouter, through the desktop gateway, which adds the key; it keeps
no data) scores each block 0-3 on how much it bears on the question, plus its yes-probability that
the block answers part of it; the rank is the sum, 0-4. Files that look like secrets are never sent.
Standard library only.
"""
import argparse, concurrent.futures as cf, html, json, os, queue, re, subprocess, sys, tempfile, threading, time
import urllib.parse, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
JEV_URL = os.environ.get("POI_JEV_URL", "http://desktop:4000/openrouter/decisions")
JEV_MODEL = os.environ.get("POI_JEV_MODEL", "typesafe/jev-1.14")
GATEWAY = os.environ.get("POI_GATEWAY", "http://desktop:4000/v1")
NVIM = os.environ.get("POI_NVIM", "nvim")
LEVELS = [
    "Nothing here bears on the question.",
    "Background only: helps understand it, but answers no part of the question.",
    "Relevant: part of what the question asks about.",
    "Directly answers part of the question.",
]
DIFF_FOCUS = "risky, surprising or behavior-changing changes worth a careful review"
BLOCK = 12          # lines per window, for files without a parser
MAX_BLOCK = 60      # lines: tree-sitter blocks bigger than this are split
PARA_MAX = 15       # lines per text paragraph block
MAX_FILE = 400_000  # bytes: bigger files are generated or data
MAX_PAGE = 2_000_000
COST = 0.000016     # dollars per Jev request, measured
SECRET = re.compile(r"(^|/)(\.env[^/]*|[^/]*\.pem|[^/]*key[^/]*|auth\.json|secrets?[^/]*|id_(rsa|ed25519|ecdsa)[^/]*|"
                    r"[^/]*\.(p12|pfx|keystore|kdbx))$", re.I)
SKIP = re.compile(r"(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|flake\.lock|poetry\.lock|"
                  r"go\.sum|[^/]*\.min\.(js|css)|[^/]*\.map)$|\.(png|jpe?g|gif|ico|pdf|zip|gz|tar|wasm|so|dylib|"
                  r"o|a|bin|exe|parquet|ttf|woff2?|mp[34]|mov|db|sqlite)$", re.I)
TEXT = re.compile(r"\.(txt|rst|adoc|org)$", re.I)
IMPORT = re.compile(r"^\s*(import |from \S+ import |use |#include|package |require[ (]|(local|const|let|var) \S+ = "
                    r"(require|await import)\b|\{ ?[a-zA-Z, .]*\}:\s*$)")


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
    """The line to jump to in a block with no definition at its head: the one sharing the most words (or word
    stems) with the question, else the first non-blank one."""
    def hits(line):
        low = line.lower()
        return sum(w[:5] in low for w in words)
    span = [n for n in range(a, b + 1) if lines[n - 1].strip()] or [a]
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


# --- tree-sitter ------------------------------------------------------------------------------

def outlines(paths):
    """{path: {"blocks": [[first, last, jump, symbols]], "outline": [...]}} from outline.lua, one headless
    Neovim per 400 files. Files with no parser are left out; so is everything if Neovim isn't there."""
    out = {}
    for i in range(0, len(paths), 400):
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
            f.write("\n".join(paths[i:i + 400]) + "\n")
        try:
            p = subprocess.run([NVIM, "--headless", "-l", os.path.join(HERE, "outline.lua"), f.name, str(MAX_BLOCK)],
                               capture_output=True, text=True, timeout=120)
        except (OSError, subprocess.TimeoutExpired):
            return out
        finally:
            os.unlink(f.name)
        for line in p.stdout.splitlines():
            try:
                r = json.loads(line)
            except ValueError:
                continue
            if r.get("blocks"):
                out[r["file"]] = r
    return out


def tidy(blocks, lines):
    """Drop blocks with next to no text (a lone brace, blank runs) and fold short unnamed ones into the next
    unnamed block when the two still fit."""
    out = []
    for a, b, jump, sym in blocks:
        body = "".join(lines[n - 1].strip() for n in range(a, min(b, len(lines)) + 1))
        if len(re.sub(r"[\W_]", "", body)) < 12:
            continue
        if out and not sym and not out[-1][3] and out[-1][1] - out[-1][0] < 3 and b - out[-1][0] < MAX_BLOCK:
            out[-1] = [out[-1][0], b, out[-1][2], ""]
            continue
        out.append([a, b, jump, sym])
    return out


def innermost(rec, line):
    """The symbol chain of the smallest named block holding `line`, or ""."""
    best = None
    for a, b, _, sym in (rec or {}).get("blocks", []):
        if sym and a <= line <= b and (best is None or b - a < best[1] - best[0]):
            best = (a, b, sym)
    return best[2] if best else ""


# --- items -------------------------------------------------------------------------------------

def gather(paths, skipped):
    """[(rel, lines)] for the text files under paths, minus secrets and generated files."""
    out, seen = [], set()
    for root in paths:
        for f in files_under(root):
            rel = os.path.relpath(f)
            if rel in seen:
                continue
            seen.add(rel)
            if SECRET.search(rel):
                skipped.append(rel)
                continue
            if SKIP.search(rel):
                continue
            s = read_text(f)
            if s and s.strip():
                out.append((rel, s.splitlines()))
    return out


def header(lines):
    imps = [line.strip() for line in lines[:80] if IMPORT.match(line)][:6]
    return ("Imports: " + " | ".join(imps) + "\n") if imps else ""


def file_item(rel, lines, rec):
    """Stage 1: a file as its path, opening lines and outline."""
    top = [line for line in lines[:12] if line.strip()][:8]
    syms = (rec or {}).get("outline", [])
    text = f"File {rel} ({len(lines)} lines). It starts:\n" + "\n".join(top)
    if syms:
        text += "\nDefinitions (line):\n" + "\n".join(syms[:80])
    else:
        text += "\n...\n" + "\n".join(lines[12:40])
    return {"file": rel, "label": f"File {rel}", "text": text[:8000]}


def block_items(rel, lines, rec, words):
    items, head = [], header(lines)
    if rec:
        spans = [(a, b, jump, sym) for a, b, jump, sym in tidy(rec["blocks"], lines)]
    else:
        spans = [(a, b, None, "") for a, b in (text_blocks if TEXT.search(rel) else code_blocks)(lines)]
    for a, b, jump, sym in spans:
        b = min(b, len(lines))
        jump = jump if (jump and sym) else best_line(lines, a, b, words)
        body = "\n".join(f"{n}\t{lines[n - 1]}" for n in range(a, b + 1))
        where = f"{rel} > {sym}" if sym else rel
        items.append({"file": rel, "a": a, "b": b, "jump": jump, "sym": sym, "where": f"{rel}:{jump}",
                      "label": f"{where}, lines {a}-{b}", "text": f"{head}Lines {a}-{b} (number, tab, text):\n{body}",
                      "preview": lines[jump - 1].strip()})
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
        out.append({"file": url, "a": i, "b": i, "jump": i, "sym": "", "where": f"passage {i}",
                    "link": f"{url.split('#')[0]}{frag}", "label": f"Passage {i} of {url}", "text": p,
                    "preview": line})
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
            n = hunk["line"] + len([x for x in hunk["lines"][1:] if x[:1] != "-"]) - 1
            items.append({"file": path, "a": hunk["line"], "b": max(hunk["line"], n), "jump": hunk["line"], "sym": "",
                          "where": f"{path}:{hunk['line']}", "label": f"Diff hunk in {path} at line {hunk['line']}",
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
    # Name the function each hunk lands in (working-tree files only; a hunk's line numbers are the new side).
    recs = outlines(sorted({it["file"] for it in items if os.path.isfile(it["file"])}))
    for it in items:
        it["sym"] = innermost(recs.get(it["file"]), it["jump"] + 3)
        if it["sym"]:
            it["label"] = f"Diff hunk in {it['file']} > {it['sym']} at line {it['jump']}"
    return items, sorted(set(skipped))


# --- Jev ---------------------------------------------------------------------------------------

def ask(question, item, what="this"):
    body = {"model": JEV_MODEL, "state": [f"Question: {question}", f"{item['label']}:\n{item['text']}"],
            "questions": {"rel": {"type": "score", "instructions": f"How much does {what} bear on the question?",
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


def rank_all(question, items, what, stats):
    """Sets item["rank"] (None on failure); adds to stats cost/failed/sent."""
    with cf.ThreadPoolExecutor(8) as ex:
        futs = {ex.submit(ask, question, it, what): it for it in items}
        for f in cf.as_completed(futs):
            try:
                futs[f]["rank"], c = f.result()
                stats["cost"] += c
            except Exception:  # noqa: BLE001
                futs[f]["rank"] = None
                stats["failed"] += 1
    stats["sent"] += len(items)
    if items and all(it["rank"] is None for it in items):
        sys.exit(f"poi: Jev unreachable at {JEV_URL} (is the desktop gateway up?)")


def merge_hits(ranked, n):
    """The top n blocks, adjacent ones in a file merged into one range; [(file, [hits])] by best hit."""
    top = ranked if n is None else ranked[:n]
    by_file = {}
    for it in top:
        by_file.setdefault(it["file"], []).append(dict(it))
    groups = []
    for f, hits in by_file.items():
        hits.sort(key=lambda h: h["a"])
        merged = []
        for h in hits:
            m = merged[-1] if merged else None
            if m and "link" not in h and h["a"] <= m["b"] + 3:
                if h["rank"] > m["rank"]:
                    m.update(rank=h["rank"], jump=h["jump"], sym=h["sym"], preview=h["preview"], where=h["where"])
                m["b"] = max(m["b"], h["b"])
                m["text"] = m["text"] + "\n" + h["text"]
            else:
                merged.append(h)
        merged.sort(key=lambda h: -h["rank"])
        groups.append((f, merged))
    groups.sort(key=lambda g: -g[1][0]["rank"])
    return groups


# --- follow: callers and references ----------------------------------------------------------------

SERVERS = {  # extension: (command, languageId)
    ".py": (["basedpyright-langserver", "--stdio"], "python"),
    ".ts": (["typescript-language-server", "--stdio"], "typescript"),
    ".tsx": (["typescript-language-server", "--stdio"], "typescriptreact"),
    ".js": (["typescript-language-server", "--stdio"], "javascript"),
    ".mjs": (["typescript-language-server", "--stdio"], "javascript"),
    ".rs": (["rust-analyzer"], "rust"),
    ".go": (["gopls"], "go"),
    ".lua": (["lua-language-server"], "lua"),
}


class Lsp:
    """Just enough of a stdio LSP client for textDocument/references."""

    def __init__(self, cmd, root):
        self.p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                  cwd=root)
        self.n, self.waiting, self.lock = 0, {}, threading.Lock()
        threading.Thread(target=self._read, daemon=True).start()
        uri = "file://" + urllib.parse.quote(root)
        self.request("initialize", {"processId": os.getpid(), "rootUri": uri,
                                    "workspaceFolders": [{"uri": uri, "name": os.path.basename(root)}],
                                    "capabilities": {"textDocument": {"references": {}},
                                                     "workspace": {"workspaceFolders": True, "configuration": True}}},
                     30)
        self.send({"jsonrpc": "2.0", "method": "initialized", "params": {}})

    def send(self, msg):
        data = json.dumps(msg).encode()
        with self.lock:
            self.p.stdin.write(b"Content-Length: %d\r\n\r\n" % len(data) + data)
            self.p.stdin.flush()

    def _read(self):
        f = self.p.stdout
        while True:
            size = None
            while True:
                line = f.readline()
                if not line:
                    return
                if line in (b"\r\n", b"\n"):
                    break
                if line.lower().startswith(b"content-length:"):
                    size = int(line.split(b":")[1])
            msg = json.loads(f.read(size))
            if "method" in msg and "id" in msg:  # the server asks us something: answer empty
                items = msg.get("params", {}).get("items")
                self.send({"jsonrpc": "2.0", "id": msg["id"],
                           "result": [None] * len(items) if msg["method"] == "workspace/configuration" else None})
            elif "id" in msg and msg["id"] in self.waiting:
                self.waiting[msg["id"]].put(msg)

    def request(self, method, params, timeout):
        self.n += 1
        q = self.waiting[self.n] = queue.Queue()
        self.send({"jsonrpc": "2.0", "id": self.n, "method": method, "params": params})
        msg = q.get(timeout=timeout)
        return msg.get("result")

    def open(self, path, lang):
        self.send({"jsonrpc": "2.0", "method": "textDocument/didOpen", "params": {"textDocument": {
            "uri": "file://" + urllib.parse.quote(path), "languageId": lang, "version": 1,
            "text": open(path, encoding="utf-8", errors="replace").read()}}})

    def close(self):
        try:
            self.request("shutdown", None, 3)
            self.send({"jsonrpc": "2.0", "method": "exit"})
            self.p.wait(3)
        except Exception:  # noqa: BLE001
            pass
        if self.p.poll() is None:
            self.p.kill()


def git_root(path):
    p = subprocess.run(["git", "-C", os.path.dirname(os.path.abspath(path)) or ".", "rev-parse", "--show-toplevel"],
                       capture_output=True, text=True)
    return p.stdout.strip() if p.returncode == 0 else os.getcwd()


def name_of(sym):
    last = sym.split(" > ")[-1]
    m = re.findall(r"[A-Za-z_$][\w$]*", last.replace("impl ", ""))
    return m[-1] if m else None


def follow(groups, limit, recs, cap=5):
    """refs[i] for the top `limit` hits: [(where, symbol, text)], from a language server when one is installed,
    else a word search with rg (marked). Each server gets 20 s to answer."""
    hits = sorted((h for _, hs in groups for h in hs if h.get("sym") and "link" not in h), key=lambda h: -h["rank"])
    hits = hits[:limit]
    servers, notes = {}, []
    for h in hits:
        name = name_of(h["sym"])
        h["refs"], h["refs_by"] = [], None
        if not name or len(name) < 3:
            continue
        path = os.path.abspath(h["file"])
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
        row = h["jump"] - 1
        col = lines[row].find(name) if row < len(lines) else -1
        ext = os.path.splitext(path)[1]
        locs = None
        if ext in SERVERS and col >= 0 and shutil_which(SERVERS[ext][0][0]):
            root = git_root(path)
            key = (ext if ext not in (".ts", ".tsx", ".js", ".mjs") else ".ts", root)
            try:
                if key not in servers:
                    servers[key] = Lsp(SERVERS[ext][0], root)
                lsp = servers[key]
                lsp.open(path, SERVERS[ext][1])
                res = lsp.request("textDocument/references", {
                    "textDocument": {"uri": "file://" + urllib.parse.quote(path)},
                    "position": {"line": row, "character": col}, "context": {"includeDeclaration": False}}, 20)
                locs = [(urllib.parse.unquote(r["uri"][7:]), r["range"]["start"]["line"] + 1) for r in res or []]
                h["refs_by"] = os.path.basename(SERVERS[ext][0][0])
            except Exception as e:  # noqa: BLE001
                notes.append(f"{SERVERS[ext][0][0]}: {type(e).__name__}")
                locs = None
        if locs is None:
            root = git_root(path)
            p = subprocess.run(["rg", "-n", "-w", "-F", "--no-heading", "-g", "!*.lock", name, root],
                               capture_output=True, text=True)
            locs = []
            for line in p.stdout.splitlines()[:200]:
                f, _, rest = line.partition(":")
                n, _, _ = rest.partition(":")
                if n.isdigit() and not (os.path.abspath(f) == path and int(n) == h["jump"]):
                    locs.append((f, int(n)))
            h["refs_by"] = "rg (word match)"
        seen = set()
        for f, n in locs:
            if (f, n) in seen or (os.path.abspath(f) == path and h["a"] <= n <= h["b"]):
                continue
            seen.add((f, n))
            rel = os.path.relpath(f)
            if SECRET.search(rel):
                continue
            if rel not in recs and os.path.isfile(f):
                recs.update(outlines([rel]))
            try:
                text = open(f, encoding="utf-8", errors="replace").read().splitlines()[n - 1].strip()
            except (OSError, IndexError):
                text = ""
            h["refs"].append((f"{rel}:{n}", innermost(recs.get(rel), n), text))
            if len(h["refs"]) >= cap:
                break
    for s in servers.values():
        s.close()
    return notes


def shutil_which(cmd):
    return any(os.access(os.path.join(d, cmd), os.X_OK) for d in os.environ.get("PATH", "").split(os.pathsep))


# --- tour ----------------------------------------------------------------------------------------

TOUR_PROMPT = """You guide a developer through code to answer their question. Below are the places a search found,
best first, each with its location, enclosing symbol and code, and sometimes who calls it.

Write a short guided read: numbered stops in the order a reader should take them to answer the question,
at most 12. Each stop is one line: `N. path:line - one or two sentences on what is there and why it matters`.
Cite only path:line locations given below (a stop may cite a line inside a place's range). End with one line
starting `Answer:` that answers the question in a sentence or two if the code shows it, else says what's missing.
No preamble."""


def tour(question, groups, model, budget_chars):
    hits = sorted((h for _, hs in groups for h in hs), key=lambda h: -h["rank"])
    parts, used = [], 0
    for h in hits:
        code = "\n".join(h["text"].split("\n")[:50])
        refs = "".join(f"\n  called at {w}" + (f" in {s}" if s else "") for w, s, _ in h.get("refs", []))
        part = f"## {h['file']}:{h['jump']} (lines {h['a']}-{h['b']})" + (f" in {h['sym']}" if h["sym"] else "") + \
               f"{refs}\n{code}\n"
        if used + len(part) > budget_chars:
            break
        parts.append(part)
        used += len(part)
    body = {"model": model, "temperature": 0.2, "max_tokens": 2048,
            "messages": [{"role": "system", "content": TOUR_PROMPT},
                         {"role": "user", "content": f"Question: {question}\n\n" + "\n".join(parts)}]}
    req = urllib.request.Request(f"{GATEWAY}/chat/completions", json.dumps(body).encode(),
                                 {"Content-Type": "application/json"})
    start = time.time()
    with urllib.request.urlopen(req, timeout=300) as r:
        d = json.load(r)
    text = d["choices"][0]["message"].get("content") or ""
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.S).strip()
    # Keep stops whose path:line lands in a place we sent (or one of its callers); drop the rest.
    real = [(h["file"], h["a"], h["b"]) for h in hits] + \
           [(w.rsplit(":", 1)[0], int(w.rsplit(":", 1)[1]), int(w.rsplit(":", 1)[1]))
            for h in hits for w, _, _ in h.get("refs", [])]
    out, dropped = [], 0
    for line in text.splitlines():
        cites = re.findall(r"([\w./@+-]+\.[\w]+):(\d+)", line)
        if re.match(r"\s*\d+\.", line) and (not cites or not all(
                any(f == c and a - 3 <= int(n) <= b + 3 for f, a, b in real) for c, n in cites)):
            dropped += 1
            continue
        out.append(line)
    return "\n".join(out).strip(), dropped, time.time() - start, d.get("usage", {})


# --- main ----------------------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(prog="poi", usage=argparse.SUPPRESS, description=__doc__.rsplit("Standard", 1)[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter, add_help=False)
    ap.add_argument("-h", "--help", action="help", help=argparse.SUPPRESS)
    ap.add_argument("args", nargs="*", help=argparse.SUPPRESS)
    ap.add_argument("--diff", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("-n", type=int, default=15, help=argparse.SUPPRESS)
    ap.add_argument("--all", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--files", type=int, default=20, help=argparse.SUPPRESS)
    ap.add_argument("--flat", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--follow", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--tour", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--tour-model", default=os.environ.get("POI_TOUR_MODEL", "flint"), help=argparse.SUPPRESS)
    ap.add_argument("--qf", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--yes", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--cap", type=int, default=600, help=argparse.SUPPRESS)
    o = ap.parse_args()
    log = lambda m: print(f"poi: {m}", file=sys.stderr)  # noqa: E731

    start, stats, skipped, recs = time.time(), {"cost": 0.0, "failed": 0, "sent": 0}, [], {}
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
        words, items = terms(question), []
        for t in targets:
            if re.match(r"https?://", t):
                try:
                    items += url_items(t, words)
                except Exception as e:  # noqa: BLE001
                    log(f"couldn't fetch {t}: {e}")
        files = gather([t for t in targets if not re.match(r"https?://", t)], skipped)
        if files:
            recs = outlines([rel for rel, _ in files if not TEXT.search(rel)])
            parsed = sum(rel in recs for rel, _ in files)
            if not o.flat and len(files) > o.files:
                fitems = [file_item(rel, lines, recs.get(rel)) for rel, lines in files]
                if len(fitems) > o.cap and not o.yes:
                    sys.exit(f"poi: {len(fitems)} files (about ${len(fitems) * COST:.3f} for the file stage); "
                             f"narrow the paths or add --yes")
                log(f"stage 1: ranking {len(fitems)} files ({parsed} parsed by tree-sitter)...")
                rank_all(question, fitems, "this file", stats)
                keep = {it["file"] for it in sorted((i for i in fitems if i["rank"] is not None),
                                                     key=lambda i: -i["rank"])[:o.files]}
                files = [(rel, lines) for rel, lines in files if rel in keep]
            for rel, lines in files:
                items += block_items(rel, lines, recs.get(rel), words)

    for s in skipped:
        log(f"skipped (looks like a secret): {s}")
    if not items:
        sys.exit("poi: nothing to rank")
    if len(items) > o.cap and not o.yes:
        sys.exit(f"poi: {len(items)} blocks (about ${len(items) * COST:.3f} and {len(items) // 8 + 1}s); "
                 f"narrow the paths, lower --files or add --yes")
    log(f"ranking {len(items)} blocks with Jev...")
    rank_all(question, items, "this", stats)
    ranked = sorted((it for it in items if it["rank"] is not None), key=lambda it: -it["rank"])
    groups = merge_hits(ranked, None if o.all else o.n)

    notes = follow(groups, 5, recs) if o.follow else []
    for n in notes:
        log(f"follow: {n}")

    if o.qf:
        for _, hits in groups:
            for h in hits:
                if "link" in h:
                    continue
                sym = f"{h['sym']} — " if h["sym"] else ""
                print(f"{h['file']}:{h['jump']}:1: [{h['rank']:.2f}] {sym}{h['preview'][:120]}")
                for w, s, t in h.get("refs", []):
                    print(f"{w}:1: ← {s + ' — ' if s else ''}{t[:100]}")
    elif o.json:
        print(json.dumps([{"file": h["file"], "line": h["jump"], "range": [h["a"], h["b"]], "rank": round(h["rank"], 2),
                           "symbol": h["sym"], "preview": h["preview"],
                           **({"link": h["link"]} if "link" in h else {}),
                           **({"refs": [{"where": w, "symbol": s, "text": t} for w, s, t in h["refs"]],
                               "refs_by": h["refs_by"]} if h.get("refs_by") else {})}
                          for _, hits in groups for h in hits], indent=1))
    else:
        for f, hits in groups:
            print(f"\033[1m{f}\033[0m" if sys.stdout.isatty() else f)
            for h in hits:
                rng = f"{h['a']}-{h['b']}" if "link" not in h else h["where"]
                sym = f"{h['sym']}  " if h["sym"] else ""
                print(f"  {h['where']}  {h['rank']:.2f}  [{rng}]  {sym}· {h['preview'][:90]}")
                if "link" in h:
                    print(f"    {h['link']}")
                for w, s, t in h.get("refs", []):
                    print(f"      ← {w}  {s + '  ' if s else ''}· {t[:80]}")
                if h.get("refs_by") and not h["refs"]:
                    print(f"      ← no callers found ({h['refs_by']})")
    note = f", {stats['failed']} failed" if stats["failed"] else ""
    log(f"{stats['sent']} Jev requests in {time.time() - start:.0f}s, ${stats['cost']:.4f}{note}")

    if o.tour:
        try:
            budget = 60_000 if o.tour_model.startswith("flint") else 30_000
            text, dropped, secs, usage = tour(question, groups, o.tour_model, budget)
        except Exception as e:  # noqa: BLE001
            sys.exit(f"poi: tour failed ({o.tour_model} at {GATEWAY}): {e}")
        print(f"\nTour ({o.tour_model}, {secs:.0f}s):\n{text}")
        if dropped:
            log(f"tour: dropped {dropped} stop(s) citing places outside the results")


if __name__ == "__main__":
    main()
