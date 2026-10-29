"""Check and bump the agent tools Configs pins by hash (npm packages, GitHub sources).

  python3 -I pin_bump.py check              newest release vs pinned, for every pin
  python3 -I pin_bump.py bump NAME [VER]    rewrite the pin to VER (default: newest release
                                            at least MIN_AGE days old) and refresh its hashes

`bump` downloads the release into a temp folder, regenerates package-lock.json with
--ignore-scripts, and builds the package once to learn npmDepsHash. It never commits, never
rebuilds the system, and prints what changed in the dependencies for review.
Standard library only; needs nix and npm on PATH.
"""
import datetime, json, os, re, shutil, subprocess, sys, tarfile, tempfile, urllib.request

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.."))
MIN_AGE = 14  # days: a compromised release usually gets pulled within days
FAKE = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

PINS = {
    "srt": {"npm": "@anthropic-ai/sandbox-runtime", "dir": "configs/sandbox-runtime"},
    "rea": {"npm": "rea-agents", "dir": "configs/rea"},
    # wabt follows REA: its WASM adapter asks for one exact version.
    "wabt": {"github": "WebAssembly/wabt", "file": "configs/rea/wabt.nix"},
}


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "pin-bump"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def run(*cmd, cwd=None, check=True):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if check and p.returncode:
        sys.exit(f"failed: {' '.join(cmd)}\n{p.stderr[-2000:]}")
    return p


def nix_file(pin):
    return os.path.join(REPO, pin.get("file") or os.path.join(pin["dir"], "default.nix"))


def pinned(pin):
    m = re.search(r'version = "([^"]+)"', open(nix_file(pin)).read())
    return m.group(1) if m else "?"


def npm_versions(name):
    d = get(f"https://registry.npmjs.org/{name.replace('/', '%2F')}")
    times = d["time"]
    return d, sorted((times[v], v) for v in d["versions"] if v in times)


def ripe(versions):
    cut = (datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None) - datetime.timedelta(days=MIN_AGE)).isoformat()
    old = [v for t, v in versions if t < cut and not re.search(r"-(alpha|beta|rc|next|canary)", v)]
    return old[-1] if old else None


def wabt_wanted():
    """The wabt version REA's adapter asks for, from the installed REA package."""
    out = run("nix", "build", "--impure", "--no-link", "--print-out-paths", "--expr",
              f"with import <nixpkgs> {{}}; callPackage {REPO}/configs/rea {{}}").stdout.strip()
    found = run("grep", "-rhoE", r"WABT [0-9]+\.[0-9]+\.[0-9]+", f"{out}/lib/node_modules/rea-agents/dist",
                check=False).stdout.split()
    vs = sorted({x for x in found if re.match(r"\d", x)})
    return vs[-1] if vs else None


def check():
    for name, pin in PINS.items():
        cur = pinned(pin)
        if "npm" in pin:
            _, vs = npm_versions(pin["npm"])
            newest, ok = vs[-1][1], ripe(vs)
            age = {v: t[:10] for t, v in vs}
            mark = "up to date" if ok == cur else f"can bump to {ok} ({age.get(ok)})"
            print(f"{name:6} pinned {cur:10} newest {newest} ({age[newest]})  -> {mark}")
        else:
            want = wabt_wanted()
            mark = "up to date" if want in (None, cur) else f"REA wants {want}: bump wabt {want}"
            print(f"{name:6} pinned {cur:10} -> {mark}")


def deps_of(lock):
    pk = json.load(open(lock)).get("packages", {})
    return {k.split("node_modules/")[-1]: v.get("version") for k, v in pk.items() if k}


def build_hash(expr):
    p = run("nix", "build", "--impure", "--no-link", "--expr", expr, check=False)
    m = re.search(r"got:\s+(sha256-[A-Za-z0-9+/=]+)", p.stderr)
    return m.group(1) if m else None, p


def bump_npm(name, pin, ver):
    d, vs = npm_versions(pin["npm"])
    ver = ver or ripe(vs)
    if not ver or ver not in d["versions"]:
        sys.exit(f"{name}: no release {ver!r}")
    meta = d["versions"][ver]
    tmp = tempfile.mkdtemp(prefix=f"pin-{name}-")
    tgz = os.path.join(tmp, "pkg.tgz")
    urllib.request.urlretrieve(meta["dist"]["tarball"], tgz)
    sri = run("nix", "hash", "file", "--type", "sha256", "--sri", tgz).stdout.strip()
    with tarfile.open(tgz) as t:
        pj = json.load(t.extractfile("package/package.json"))
    scripts = {k: v for k, v in pj.get("scripts", {}).items() if "install" in k}
    for k in ("devDependencies", "scripts", "optionalDependencies"):
        pj.pop(k, None)
    lockdir = os.path.join(tmp, "lock")
    os.makedirs(lockdir)
    json.dump(pj, open(os.path.join(lockdir, "package.json"), "w"), indent=2)
    run("npm", "install", "--package-lock-only", "--ignore-scripts", "--omit=dev", cwd=lockdir)

    dst = os.path.join(REPO, pin["dir"])
    before = deps_of(os.path.join(dst, "package-lock.json"))
    after = deps_of(os.path.join(lockdir, "package-lock.json"))
    for f in ("package.json", "package-lock.json"):
        shutil.copy(os.path.join(lockdir, f), os.path.join(dst, f))
    nf = nix_file(pin)
    s = open(nf).read()
    s = re.sub(r'version = "[^"]+"', f'version = "{ver}"', s, count=1)
    s = re.sub(r'(src = fetchurl \{[^}]*?hash = ")[^"]+"', rf'\g<1>{sri}"', s, count=1, flags=re.S)
    s = re.sub(r'npmDepsHash = "[^"]+"', f'npmDepsHash = "{FAKE}"', s)
    open(nf, "w").write(s)
    run("git", "add", pin["dir"], cwd=REPO)  # flakes and <nixpkgs> builds only see tracked files
    expr = f"with import <nixpkgs> {{}}; callPackage {dst} {{}}"
    h, _ = build_hash(expr)
    if not h:
        sys.exit("couldn't learn npmDepsHash; build output above")
    open(nf, "w").write(s.replace(FAKE, h))
    _, p = build_hash(expr)
    if p.returncode:
        sys.exit(f"build failed after bump:\n{p.stderr[-2000:]}")

    print(f"{name}: {pinned(pin)} built. Review before committing:")
    added = sorted(set(after) - set(before))
    removed = sorted(set(before) - set(after))
    changed = sorted(k for k in set(after) & set(before) if after[k] != before[k])
    print(f"  deps: +{len(added)} -{len(removed)} changed {len(changed)}")
    for k in added:
        print(f"    + {k} {after[k]}")
    for k in removed:
        print(f"    - {k}")
    if scripts:
        print(f"  NOTE install scripts in the package (we run with --ignore-scripts): {scripts}")
    print(f"  changelog: https://www.npmjs.com/package/{pin['npm']}/v/{ver}")
    shutil.rmtree(tmp, ignore_errors=True)


def bump_github(name, pin, ver):
    ver = ver or wabt_wanted()
    if not ver:
        sys.exit(f"{name}: say which version")
    nf = nix_file(pin)
    s = open(nf).read()
    s = re.sub(r'version = "[^"]+"', f'version = "{ver}"', s, count=1)
    s = re.sub(r'hash = "[^"]+"', f'hash = "{FAKE}"', s, count=1)
    open(nf, "w").write(s)
    expr = f"with import <nixpkgs> {{}}; callPackage {nf} {{}}"
    h, _ = build_hash(expr)
    if not h:
        sys.exit("couldn't learn the source hash")
    open(nf, "w").write(s.replace(FAKE, h))
    _, p = build_hash(expr)
    if p.returncode:
        sys.exit(f"build failed after bump:\n{p.stderr[-2000:]}")
    print(f"{name}: {ver} built. Release notes: https://github.com/{pin['github']}/releases/tag/{ver}")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["check"]:
        check()
    elif a[:1] == ["bump"] and len(a) >= 2 and a[1] in PINS:
        pin = PINS[a[1]]
        (bump_npm if "npm" in pin else bump_github)(a[1], pin, a[2] if len(a) > 2 else None)
    else:
        sys.exit(__doc__)
