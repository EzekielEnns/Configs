"""poi: points of interest. Jev ranks code, diff hunks or web passages against a question and
prints a jump list, best first, grouped by file.

  poi "question" [PATH|URL ...]       rank code and docs under PATHs (default .) or page text
  poi --diff [REF|RANGE] ["focus"]    rank diff hunks: working tree vs HEAD, vs REF, or A...B

  -n N        show the top N places (default 15)     --all     show everything
  --files K   rank files first, then dig into the top K (default 20)
  --flat      skip the file stage: rank every block
  --follow    under each of the top 5 hits, its callers and references (language server, else rg)
  --tour      a local model turns the hits into a short guided read (--tour-model, default flint)
  --flow      order the places the way data moves: where it starts (client) to where it ends (storage),
              infrastructure where the data passes through it (Jev places each step), and within that
              each function before what it calls (language-server call hierarchy, else the text). With
              --diff, call order only; good for PR review
  --qf        Vim quickfix lines on stdout:  poi --qf "question" | nvim -q -   (or nvim -q <(poi --qf ...))
  --open      open the result in Neovim (:PoiLoad): a Rex pane to the right when inside Rex
  --json      one line of JSON: hits (and tour stops / flow steps), paths relative to "root", and the cost
  --no-links  plain path:line (default: OSC 8 nvim-open:// links when stdout is a terminal)
  --yes       go past the cost cap    --cap N   Jev requests before asking for --yes (default 600)

Code is cut with tree-sitter (headless Neovim, poi's own parsers): a block is a whole function,
class, method or Nix binding, long ones split at statement boundaries, with the code between them
in blocks of its own. Each block goes to Jev with its path, its enclosing symbols and the file's
imports. Files without a parser fall back to 12-line windows, Markdown and text to paragraphs.

Jev (a decision model on OpenRouter, through the desktop gateway, which adds the key; it keeps
no data) scores each block 0-3 on how much it bears on the question, plus its yes-probability that
the block answers part of it; the rank is the sum, 0-4. Files that look like secrets are never sent.
Standard library only.
"""
import argparse, concurrent.futures as cf, html, json, os, queue, re, shlex, subprocess, sys, tempfile, threading, time
import urllib.error, urllib.parse, urllib.request

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
# Files that hold secrets by name or type. Source code is never matched by name alone
# (keys.go, keyboard.ts), and example env files are fine.
SECRET = re.compile(r"(^|/)(\.env(?!\.(example|sample|template|dist)$)[^/]*|\.envrc|\.netrc|\.npmrc|\.pypirc|"
                    r"auth\.json|credentials?|secrets?|id_(rsa|ed25519|ecdsa)[^/]*|"
                    r"[^/]*\.(pem|key|p12|pfx|keystore|jks|kdbx|gpg)|"
                    r"[^/]*(key|keys|credentials?|secrets?|tokens?)\.(json|ya?ml|txt|ini|cfg|conf|toml|env))$", re.I)
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

CACHE_PATH = os.environ.get("POI_JEV_CACHE")  # tests: reuse Jev's answers for the same question and block
CACHE = json.load(open(CACHE_PATH)) if CACHE_PATH and os.path.exists(CACHE_PATH) else {}
CACHE_LOCK = threading.Lock()


def ask(question, item, what="this"):
    if CACHE_PATH:
        key = __import__("hashlib").sha1(f"{question}\0{what}\0{item['label']}\0{item['text']}".encode()).hexdigest()
        if key in CACHE:
            return CACHE[key], 0.0
        r = ask_jev(question, item, what)
        with CACHE_LOCK:
            CACHE[key] = r[0]
            json.dump(CACHE, open(CACHE_PATH, "w"))
        return r
    return ask_jev(question, item, what)


def ask_jev(question, item, what="this"):
    if os.environ.get("POI_JEV_STUB"):  # tests without Jev: question words in the text, 0-4
        low = item["text"].lower() + item["label"].lower()
        return min(4.0, 0.6 * sum(w[:5] in low for w in terms(question))), 0.0
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
        except urllib.error.HTTPError as e:
            msg = e.read().decode("utf-8", "replace")
            try:
                msg = json.loads(msg)["error"]["message"]
            except (ValueError, KeyError, TypeError):
                pass
            if attempt or e.code in (401, 402, 403):
                raise RuntimeError(f"HTTP {e.code}: {msg[:300]}") from None
            time.sleep(1)
        except Exception:  # noqa: BLE001 - one retry, then the caller reports it
            if attempt:
                raise
            time.sleep(1)


def rank_all(question, items, what, stats):
    """Sets item["rank"] (None on failure); adds to stats cost/failed/sent."""
    last = None
    with cf.ThreadPoolExecutor(8) as ex:
        futs = {ex.submit(ask, question, it, what): it for it in items}
        for f in cf.as_completed(futs):
            try:
                futs[f]["rank"], c = f.result()
                stats["cost"] += c
            except Exception as e:  # noqa: BLE001
                futs[f]["rank"] = None
                stats["failed"] += 1
                last = e
    stats["sent"] += len(items)
    if items and all(it["rank"] is None for it in items):
        sys.exit(f"poi: Jev failed at {JEV_URL}: {last}")


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
                                    "capabilities": {"textDocument": {"references": {}, "callHierarchy": {}},
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

    def outgoing(self, path, row, col, timeout=15):
        """[(file, line of the callee, line of the call site)] via callHierarchy."""
        uri = "file://" + urllib.parse.quote(path)
        items = self.request("textDocument/prepareCallHierarchy",
                             {"textDocument": {"uri": uri}, "position": {"line": row, "character": col}}, timeout)
        out = []
        for it in (items or [])[:1]:
            for c in self.request("callHierarchy/outgoingCalls", {"item": it}, timeout) or []:
                to = c["to"]
                site = (c.get("fromRanges") or [{"start": {"line": row}}])[0]["start"]["line"] + 1
                out.append((urllib.parse.unquote(to["uri"][7:]), to["selectionRange"]["start"]["line"] + 1, site))
        return out

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


# --- flow: order the hits along the call graph ---------------------------------------------------

GENERIC = {"open", "close", "read", "send", "init", "self", "test", "data", "text", "name", "file", "path", "args",
           "main", "config", "options", "result", "value", "items", "lines", "default"}
COMMENT = re.compile(r"\s*(#|//|/?\*|--|;)")
ENTRY = re.compile(r"(^|_|\b)(main|handler|handle|cli|run|start|default|on[A-Z_]|serve|entry)", re.I)


def flow_nodes(groups, recs):
    """The hits as functions: one node per (file, top symbol), spanning every block of that function."""
    nodes, by_key = [], {}
    for _, hits in groups:
        for h in hits:
            if "link" in h:
                continue
            sym = h["sym"].split(" > ")[0] if h["sym"] else ""
            key = (h["file"], sym or f"@{h['a']}")
            if key in by_key:
                n = by_key[key]
                n["rank"] = max(n["rank"], h["rank"])
                n["hits"].append(h)
                continue
            a, b, jump = h["a"], h["b"], h["jump"]
            rec = recs.get(h["file"])
            if sym and rec:
                spans = [(x, y, j) for x, y, j, s in rec["blocks"] if s == sym or s.startswith(sym + " > ")]
                if spans:
                    a, b = min(x for x, _, _ in spans), max(y for _, y, _ in spans)
                    jump = min(spans)[2]
            n = {"file": h["file"], "sym": sym, "name": name_of(sym) if sym else None, "a": a, "b": b, "jump": jump,
                 "rank": h["rank"], "hits": [h], "edges": []}
            by_key[key] = n
            nodes.append(n)
    return nodes


def flow_edges(nodes, use_lsp=True):
    """n["edges"] = [(call-site line, target node)]: from language-server call hierarchy where one answers,
    else from the text (a call `name(`, a Nix/attr use of `name`, or a mention of another file's name)."""
    files = {}

    def body(n):
        if n["file"] not in files:
            files[n["file"]] = open(n["file"], encoding="utf-8", errors="replace").read().splitlines()
        return files[n["file"]]

    def target(f, line):
        for m in nodes:
            if m["file"] == f and m["a"] <= line <= m["b"]:
                return m
        return None

    servers, by = {}, set()
    for n in nodes:
        got = False
        ext = os.path.splitext(n["file"])[1]
        if use_lsp and n["name"] and ext in SERVERS and shutil_which(SERVERS[ext][0][0]):
            path = os.path.abspath(n["file"])
            row = n["jump"] - 1
            col = body(n)[row].find(n["name"]) if row < len(body(n)) else -1
            if col >= 0:
                key = (".ts" if ext in (".ts", ".tsx", ".js", ".mjs") else ext, git_root(path))
                try:
                    if key not in servers:
                        servers[key] = Lsp(SERVERS[ext][0], key[1])
                    servers[key].open(path, SERVERS[ext][1])
                    for f, line, site in servers[key].outgoing(path, row, col):
                        m = target(os.path.relpath(f), line)
                        if m and m is not n:
                            n["edges"].append((site, m))
                            got = True
                    by.add(os.path.basename(SERVERS[ext][0][0]))
                except Exception:  # noqa: BLE001 - fall back to the text
                    pass
        if got:
            continue
        lines = body(n)
        for m in nodes:
            if m is n or (m["file"] == n["file"] and not (m["b"] < n["a"] or m["a"] > n["b"])):
                continue
            pats = []
            if m["name"] and len(m["name"]) >= 4 and m["name"] not in GENERIC:
                pats.append(re.compile(r"\b" + re.escape(m["name"]) + (r"\b" if m["file"].endswith(".nix")
                                                                       else r"\s*\(")))
            if m["file"] != n["file"]:
                base = os.path.basename(m["file"])
                if len(base) > 4 and base not in ("default.nix", "index.ts", "__init__.py"):
                    first = min((x for x in nodes if x["file"] == m["file"]), key=lambda x: x["a"])
                    if first is m:  # a mention of the file, or of a command named like it (pi-sandbox)
                        stem = os.path.splitext(base)[0]
                        plain = len(stem) < 6 or not re.search(r"[-_.]|[a-z][A-Z]", stem)  # "agents" is a word
                        pats.append(re.compile(re.escape(base) if plain
                                               else r"(?<![\w.-])" + re.escape(stem) + r"(?![\w-])"))
            for i in range(n["a"], min(n["b"], len(lines)) + 1):
                if i == n["jump"] or COMMENT.match(lines[i - 1]):
                    continue
                code = re.split(r"\s(#|//|--)\s", lines[i - 1])[0]  # not in a trailing comment
                if any(p.search(code) for p in pats):
                    n["edges"].append((i, m))
                    by.add("text")
                    break
    for s in servers.values():
        s.close()
    # Top-level code outside any function runs top to bottom: chain a file's unnamed steps in line order.
    for f in {n["file"] for n in nodes}:
        loose = sorted((n for n in nodes if n["file"] == f and not n["sym"]), key=lambda n: n["a"])
        for x, y in zip(loose, loose[1:]):
            if not any(m is y for _, m in x["edges"]):
                x["edges"].append((x["b"], y))
                by.add("line order")
    return by


STAGES = [
    "Where the data starts: the client, browser, device, UI or user input that produces or collects it.",
    "Carrying it in: the client sending it, the network path, gateway, load balancer or the endpoint that receives it.",
    "Server-side work: handlers, queues and topics, workers and the logic that processes it.",
    "Where it ends: databases, buckets, files, reports, or the answer sent back.",
]
STAGE_NAMES = ["client", "in", "server", "end"]


def flow_stages(question, hits, stats):
    """{index: (stage 0-3, on the data's path 0-1)} for flow steps, from Jev: --flow reads code the way data moves,
    client to server to storage, with infrastructure where the data passes through it."""
    def one(h):
        item = {"label": f"{h['file']}:{h['jump']}" + (f" {h['sym']}" if h["sym"] else ""), "text": h["text"][:6000]}
        if os.environ.get("POI_JEV_STUB"):
            low = (item["label"] + item["text"]).lower()
            st = 0 if any(w in low for w in ("client", "browser", "ui")) else 3 if any(w in low for w in ("db", "store")) else 2
            return st, 1.0, 0.0
        body = {"model": JEV_MODEL, "state": [f"Question: {question}", f"{item['label']}:\n{item['text']}"],
                "questions": {"stage": {"type": "score", "criteria": STAGES, "instructions":
                                        "Where on the data's path through the system does this code or config sit?"},
                              "path": {"type": "noul", "instructions": "This code or config produces, carries, "
                                       "processes or stores the data the question is about (build scripts, CI and "
                                       "tests do not)."}}}
        req = urllib.request.Request(JEV_URL, json.dumps(body).encode(), {"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r:
            d = json.load(r)
        a = d["answers"]
        return float(a["stage"]["score"]), float(a["path"]["noul"]), float(d.get("usage", {}).get("cost", 0))

    out = {}
    with cf.ThreadPoolExecutor(8) as ex:
        futs = {ex.submit(one, h): i for i, h in enumerate(hits)}
        for f in cf.as_completed(futs):
            try:
                st, on, c = f.result()
                out[futs[f]] = (st, on)
                stats["cost"] += c
            except Exception:  # noqa: BLE001 - that step keeps its call-graph place
                stats["failed"] += 1
    stats["sent"] += len(hits)
    return out


def by_stage(order, stages):
    """The call-ordered steps, regrouped along the data's path: each run of linked steps (a caller and what it
    calls) moves as one, placed by its earliest stage; steps off the data's path go last, marked."""
    chunks, cur = [], []
    for i, h in enumerate(order):
        if cur and not (h["flow_unknown"] or cur[-1]["flow_unknown"]) and any(
                f"{h['file']}:{h['jump']}" == c for x in cur for c in x.get("calls", [])):
            cur.append(h)
        else:
            if cur:
                chunks.append(cur)
            cur = [h]
    if cur:
        chunks.append(cur)
    idx = {id(h): i for i, h in enumerate(order)}

    def key(ch):
        st = [stages[idx[id(h)]] for h in ch if idx[id(h)] in stages]
        off = bool(st) and max(on for _, on in st) < 0.5
        return (off, min(s for s, _ in st) if st else 1.5, idx[id(ch[0])])

    out = []
    for ch in sorted(chunks, key=key):
        off = key(ch)[0]
        for h in ch:
            sv = stages.get(idx[id(h)])
            out.append({**h, "flow_unknown": off,
                        "stage": STAGE_NAMES[min(3, max(0, round(sv[0])))] if sv and not off else None})
    return out


def flow_order(nodes):
    """Reading order: depth-first from the entry points (no incoming edge among the hits; names like main or
    handle first, then by rank), each node's callees in call-site order. Nodes with no edge at all come last,
    marked flow_unknown."""
    incoming = {id(n): 0 for n in nodes}
    for n in nodes:
        for _, m in n["edges"]:
            incoming[id(m)] += 1
    linked = [n for n in nodes if n["edges"] or incoming[id(n)]]
    roots = sorted((n for n in linked if not incoming[id(n)]),
                   key=lambda n: (not ENTRY.search(n["name"] or ""), -n["rank"], n["file"], n["a"]))
    order, seen = [], set()

    def visit(n):
        if id(n) in seen:
            return
        seen.add(id(n))
        order.append(n)
        for _, m in sorted(n["edges"], key=lambda e: e[0]):
            visit(m)

    for r in roots:
        visit(r)
    out_deg = {id(n): len(n["edges"]) for n in nodes}
    for n in sorted(linked, key=lambda n: (incoming[id(n)] - out_deg[id(n)], -n["rank"])):  # cycles: most-calling first
        visit(n)
    for n in sorted((n for n in nodes if id(n) not in seen), key=lambda n: -n["rank"]):
        n["flow_unknown"] = True
        order.append(n)
        seen.add(id(n))
    return order


def as_hit(n):
    """A flow node in the shape the tour and the printers take."""
    h = max(n["hits"], key=lambda h: h["rank"])
    lines = open(n["file"], encoding="utf-8", errors="replace").read().splitlines()
    b = min(n["b"], n["a"] + 59, len(lines))
    text = "\n".join(f"{i}\t{lines[i - 1]}" for i in range(n["a"], b + 1)) if not h["text"].startswith("@@") \
        else "\n".join(x["text"] for x in n["hits"])
    return {**h, "a": n["a"], "b": n["b"], "jump": n["jump"] if n["sym"] else h["jump"], "sym": n["sym"] or h["sym"],
            "rank": n["rank"], "text": text, "flow_unknown": n.get("flow_unknown", False),
            "calls": [f"{m['file']}:{m['jump']}" for _, m in sorted(n["edges"], key=lambda e: e[0])]}


def reorder_unknown(order, stops):
    """Put the steps with no known edge where the tour model placed them; known steps keep their order."""
    pos = {(h["file"], h["jump"]): h for h in order}

    def find(s):
        for h in order:
            if h["file"] == s["file"] and h["a"] - 3 <= s["line"] <= h["b"] + 3:
                return h
        return pos.get((s["file"], s["line"]))

    seq = []
    for s in stops:
        h = find(s)
        if h is not None and h not in seq:
            seq.append(h)
    known = iter([h for h in order if not h["flow_unknown"]])
    out = []
    for h in seq:
        out.append(h if h["flow_unknown"] else next(known, None))
    out = [h for h in out if h is not None]
    out += [h for h in order if h not in out]
    return out


# --- tour ----------------------------------------------------------------------------------------

TOUR_PROMPT = """You guide a developer through code to answer their question. Below are the places a search found,
best first, each with its location, enclosing symbol and code, and sometimes who calls it.

Write a short guided read: numbered stops in the order a reader should take them to answer the question,
at most 12. Each stop is one line: `N. path:line - one or two sentences on what is there and why it matters`.
Cite only path:line locations given below (a stop may cite a line inside a place's range). End with one line
starting `Answer:` that answers the question in a sentence or two if the code shows it, else says what's missing.
No preamble."""

FLOW_PROMPT = """You explain one flow through code to a developer. Below are the steps a search found, in the
order data moves through them (S1 first): from where it starts (client) to where it ends (storage), with
infrastructure where the data passes through it. Steps marked "off the data path" go wherever they fit.

Write one line per step, in flow order, at most 12: `N. path:line - what comes into this step and what it
hands on (data, calls, side effects)`. Cite only the path:line given for each step. End with one line starting
`Answer:` that sums up the flow in a sentence or two. No preamble."""

STOP = re.compile(r"^\s*\**\s*(\d+)[.)]\s*\**\s*`?([\w./@+-]+\.\w+):(\d+)`?\s*\**\s*[-—–:]*\s*(.*)$")


def tour(question, hits, model, budget_chars, flow=False):
    """A local model's guided read over `hits` (in the order given). Returns {"stops": [...], "answer",
    "dropped", "seconds", "model", "usage"}; stops whose path:line isn't one of the places sent (or their
    callers) are dropped."""
    parts, used, sent = [], 0, []
    for i, h in enumerate(hits, 1):
        code = "\n".join(h["text"].split("\n")[:50])
        refs = "".join(f"\n  called at {w}" + (f" in {s}" if s else "") for w, s, _ in h.get("refs", []))
        tag = f"S{i}. " if flow else ""
        unk = " (off the data path)" if flow and h.get("flow_unknown") else ""
        part = f"## {tag}{h['file']}:{h['jump']} (lines {h['a']}-{h['b']})" + \
               (f" in {h['sym']}" if h["sym"] else "") + f"{unk}{refs}\n{code}\n"
        if used + len(part) > budget_chars:
            break
        parts.append(part)
        sent.append(h)
        used += len(part)
    body = {"model": model, "temperature": 0.2, "max_tokens": 6144,
            "messages": [{"role": "system", "content": FLOW_PROMPT if flow else TOUR_PROMPT},
                         {"role": "user", "content": f"Question: {question}\n\n" + "\n".join(parts)}]}
    req = urllib.request.Request(f"{GATEWAY}/chat/completions", json.dumps(body).encode(),
                                 {"Content-Type": "application/json"})
    start = time.time()
    with urllib.request.urlopen(req, timeout=300) as r:
        d = json.load(r)
    text = d["choices"][0]["message"].get("content") or ""
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.S).strip()

    def place(f, n):
        for h in sent:
            if h["file"] == f and h["a"] - 3 <= n <= h["b"] + 3:
                return h["b"], h["sym"]
            for w, s, _ in h.get("refs", []):
                if w == f"{f}:{n}":
                    return n, s
        return None

    stops, answer, dropped = [], "", 0
    for line in text.splitlines():
        m = STOP.match(line)
        if m:
            f, n = m.group(2), int(m.group(3))
            p = place(f, n)
            if not p:
                dropped += 1
                continue
            stops.append({"file": f, "line": n, "end": p[0], "symbol": p[1],
                          "text": m.group(4).strip().strip("*").strip()})
        elif line.strip().lstrip("*").lower().startswith("answer:"):
            answer = line.strip().lstrip("*").split(":", 1)[1].strip().strip("*").strip()
        elif re.match(r"\s*\d+[.)]", line):
            dropped += 1
    return {"stops": stops[:12], "answer": answer, "dropped": dropped, "seconds": round(time.time() - start, 1),
            "model": model, "usage": d.get("usage", {})}


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
    ap.add_argument("--flow", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--open", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--links", dest="links", action="store_true", default=None, help=argparse.SUPPRESS)
    ap.add_argument("--no-links", dest="links", action="store_false", help=argparse.SUPPRESS)
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
    jev_secs = time.time() - start

    # Flow: the hits as functions, in call order; otherwise by rank, grouped by file.
    flow_by = None
    if o.flow:
        if o.diff:  # hunks need their functions' outlines for the call graph
            recs.update(outlines(sorted({h["file"] for _, hs in groups for h in hs if os.path.isfile(h["file"])})))
        nodes = flow_nodes(groups, recs)
        flow_by = sorted(flow_edges(nodes))
        ordered = [as_hit(n) for n in flow_order(nodes)]
        if not o.diff:  # a diff's hunks keep call order; a search reads client to server to storage
            ordered = by_stage(ordered, flow_stages(question, ordered, stats))
        log(f"flow: {sum(len(n['edges']) for n in nodes)} call edges among {len(nodes)} functions "
            f"({', '.join(flow_by) or 'none found'})")
    hits = ordered if o.flow else [h for _, hs in groups for h in hs]

    tr = None
    if o.tour:
        try:
            budget = 60_000 if o.tour_model.startswith("flint") else 30_000
            tr = tour(question, hits, o.tour_model, budget, flow=o.flow)
        except Exception as e:  # noqa: BLE001
            sys.exit(f"poi: tour failed ({o.tour_model} at {GATEWAY}): {e}")
        if tr["dropped"]:
            log(f"tour: dropped {tr['dropped']} stop(s) citing places outside the results")
        if o.flow:
            hits = reorder_unknown(hits, tr["stops"])

    cost = {"jev_requests": stats["sent"], "jev_failed": stats["failed"], "usd": round(stats["cost"], 5),
            "seconds": round(time.time() - start, 1)}
    if tr:
        cost["tour_seconds"] = tr["seconds"]
    result = build_result(question, o, hits, tr, flow_by, cost)
    note = f", {stats['failed']} failed" if stats["failed"] else ""
    log(f"{stats['sent']} Jev requests in {jev_secs:.0f}s, ${stats['cost']:.4f}{note}")

    if o.open:
        open_in_editor(result)
    elif o.qf:
        print_qf(result)
    elif o.json:
        print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    else:
        links = o.links if o.links is not None else sys.stdout.isatty()
        print_text(result, groups if not o.flow else None, links)


def stop_text(h, tr_stop):
    if tr_stop:
        return tr_stop["text"]
    return (f"{h['sym']} — " if h["sym"] else "") + h["preview"][:120]


def build_result(question, o, hits, tr, flow_by, cost):
    """The stable --json shape (also what :Poi and --open read). Paths are relative to `root`."""
    def stop_for(h):
        for s in (tr or {}).get("stops", []):
            if s["file"] == h["file"] and h["a"] - 3 <= s["line"] <= h["b"] + 3:
                return s
        return None

    out_hits = []
    for i, h in enumerate(hits, 1):
        d = {"file": h["file"], "line": h["jump"], "end": h["b"], "start": h["a"], "score": round(h["rank"], 2),
             "symbol": h["sym"], "preview": h["preview"][:160]}
        if "link" in h:
            d["url"] = h["link"]
        if o.flow:
            d["step"] = i
            d["text"] = stop_text(h, stop_for(h))
            if h.get("calls"):
                d["calls"] = h["calls"]
            if h.get("stage"):
                d["stage"] = h["stage"]
            if h.get("flow_unknown"):
                d["order_unknown"] = True
        if h.get("refs_by"):
            d["refs"] = [{"file": w.rsplit(":", 1)[0], "line": int(w.rsplit(":", 1)[1]), "symbol": s, "text": t[:120]}
                         for w, s, t in h["refs"]]
            d["refs_by"] = h["refs_by"]
        out_hits.append(d)
    res = {"question": question, "mode": "diff" if o.diff else "search", "root": os.getcwd(), "hits": out_hits}
    if o.flow:
        res["flow"] = {"edges_by": flow_by}
    if tr:
        res["tour"] = {"model": tr["model"], "answer": tr["answer"],
                       "stops": [{"step": i, **s} for i, s in enumerate(tr["stops"], 1)]}
    res["cost"] = cost
    return res


def stops_of(result):
    """What to walk: flow steps, else tour stops, else hits; as (file, line, end, text)."""
    if "flow" in result:
        return [(h["file"], h["line"], h["end"], f"{h['step']}. {h['text']}") for h in result["hits"] if "url" not in h]
    if result.get("tour", {}).get("stops"):
        return [(s["file"], s["line"], s["end"], f"{s['step']}. {s['text']}") for s in result["tour"]["stops"]]
    return [(h["file"], h["line"], h["end"], f"[{h['score']:.2f}] " + (f"{h['symbol']} — " if h["symbol"] else "")
             + h["preview"]) for h in result["hits"] if "url" not in h]


def print_qf(result):
    for f, n, _, text in stops_of(result):
        print(f"{f}:{n}:1: {text}")
    if "flow" not in result and not result.get("tour"):
        for h in result["hits"]:
            for r in h.get("refs", []):
                print(f"{r['file']}:{r['line']}:1: ← {(r['symbol'] + ' — ') if r['symbol'] else ''}{r['text']}")


HOST = None


def osc8(path, line, text, on):
    """`text` as a terminal hyperlink to nvim-open://open?file=...&line=...&host=... (the editor-side handler opens
    it in Neovim on that machine)."""
    global HOST
    if not on:
        return text
    if HOST is None:
        HOST = subprocess.run(["hostname", "-s"], capture_output=True, text=True).stdout.strip() or "localhost"
    url = "nvim-open://open?" + urllib.parse.urlencode({"file": os.path.abspath(path), "line": line, "host": HOST})
    return f"\033]8;;{url}\033\\{text}\033]8;;\033\\"


def print_text(result, groups, links):
    bold = (lambda s: f"\033[1m{s}\033[0m") if sys.stdout.isatty() else (lambda s: s)
    hits = result["hits"]
    if "flow" in result:
        print(bold(f"Flow ({len(hits)} steps, call edges from {', '.join(result['flow']['edges_by']) or 'nothing'}):"))
        for h in hits:
            where = f"{h['file']}:{h['line']}"
            mark = "  (off the data path)" if h.get("order_unknown") else ""
            stage = f"[{h['stage']}] " if h.get("stage") else ""
            print(f"  {h['step']:>2}. {stage}{osc8(h['file'], h['line'], where, links)}  {h['text'][:110]}{mark}")
            for c in h.get("calls", []):
                f, n = c.rsplit(":", 1)
                print(f"        → {osc8(f, int(n), c, links)}")
    else:
        order, by_file = [], {}
        for h in hits:
            if h["file"] not in by_file:
                order.append(h["file"])
            by_file.setdefault(h["file"], []).append(h)
        for f in order:
            print(bold(f))
            for h in by_file[f]:
                if "url" in h:
                    print(f"  passage {h['line']}  {h['score']:.2f}  · {h['preview'][:90]}\n    {h['url']}")
                    continue
                where = osc8(h["file"], h["line"], f"{h['file']}:{h['line']}", links)
                sym = f"{h['symbol']}  " if h["symbol"] else ""
                print(f"  {where}  {h['score']:.2f}  [{h['start']}-{h['end']}]  {sym}· {h['preview'][:90]}")
                for r in h.get("refs", []):
                    w = osc8(r["file"], r["line"], f"{r['file']}:{r['line']}", links)
                    print(f"      ← {w}  {r['symbol'] + '  ' if r['symbol'] else ''}· {r['text'][:80]}")
                if h.get("refs_by") and not h.get("refs"):
                    print(f"      ← no callers found ({h['refs_by']})")
    tr = result.get("tour")
    if tr:
        print(bold(f"\nTour ({tr['model']}, {result['cost'].get('tour_seconds', 0):.0f}s):"))
        for s in tr["stops"]:
            where = osc8(s["file"], s["line"], f"{s['file']}:{s['line']}", links)
            print(f"  {s['step']:>2}. {where}  {s['text']}")
        if tr["answer"]:
            print(f"  Answer: {tr['answer']}")


def open_in_editor(result):
    """Write the result to a temp file and open it in Neovim: a Rex pane to the right when inside Rex, else print
    how to open it."""
    fd, path = tempfile.mkstemp(prefix="poi-", suffix=".json")
    with os.fdopen(fd, "w") as f:
        json.dump(result, f)
    if os.environ.get("REX_SESSION") and shutil_which("rex"):
        cmd = ["rex", "split", "--split=right", "--json", "-c", os.getcwd(), "--label", "poi"]
        if os.environ.get("REX_BLOCK"):
            cmd += ["-b", os.environ["REX_BLOCK"]]
        cmd += ["--"] + shlex.split(os.environ.get("POI_EDITOR", "nvim")) + ["-c", f"PoiLoad {path}"]
        p = subprocess.run(cmd, capture_output=True, text=True)
        if p.returncode == 0:
            ids = [b for b in re.findall(r"block:[0-9a-f-]+", p.stdout) if b != os.environ.get("REX_BLOCK")]
            print(f"poi: opened in a Rex pane{' ' + ids[0] if ids else ''} ({len(stops_of(result))} stops; "
                  f"]q / [q to walk them)", file=sys.stderr)
            return
        print(f"poi: rex split failed: {p.stderr.strip()}", file=sys.stderr)
    qf = path[:-5] + ".qf"
    with open(qf, "w") as f:
        for fl, n, _, text in stops_of(result):
            f.write(f"{fl}:{n}:1: {text}\n")
    print(f"poi: saved {path}\n  nvim -c 'PoiLoad {path}'   (with the :Poi plugin)\n  nvim -q {qf}")


if __name__ == "__main__":
    main()
