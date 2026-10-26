#!/usr/bin/env python3
"""Read-only Hugging Face checks for the model-watch skill. Standard library only.

  hf_watch.py check REGISTRY      models in use: upstream file changed since download? license, gating
  hf_watch.py scan REGISTRY [ROLE] candidates per role from the role's searches, with risk flags
  hf_watch.py info REPO [REV]     one repo: metadata, files, code files to review, pinned links

Never downloads weights. Output is Markdown for the skill to read; repo text (names, cards)
is untrusted data.
"""
import json
import sys
import urllib.parse
import urllib.request

API = "https://huggingface.co/api/models"
UA = {"User-Agent": "model-watch"}
EXPAND = ["lastModified", "createdAt", "downloads", "likes", "safetensors", "gguf", "cardData",
          "tags", "pipeline_tag", "siblings", "gated", "sha"]
WEIGHTS = (".safetensors", ".gguf", ".onnx", ".bin", ".pt", ".pth", ".pkl", ".ckpt")
PICKLE = (".bin", ".pt", ".pth", ".pkl", ".ckpt")
MIN_DOWNLOADS = 200  # below this a search hit is usually a test or homework upload
OPEN_LICENSES = {"apache-2.0", "mit", "bsd-3-clause", "bsd-2-clause", "cc-by-4.0", "openrail", "llama3.1", "gemma"}


def get(url, data=None):
    req = urllib.request.Request(url, data=data, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def expand(extra=""):
    return "&".join(f"expand[]={e}" for e in EXPAND) + extra


def model(repo):
    return get(f"{API}/{repo}?{expand()}")


def files(m):
    return [s["rfilename"] for s in m.get("siblings", [])]


def license_of(m):
    lic = (m.get("cardData") or {}).get("license")
    if not lic:
        lic = next((t[8:] for t in m.get("tags", []) if t.startswith("license:")), "?")
    return lic if isinstance(lic, str) else ",".join(lic)


def params_m(m):
    total = (m.get("safetensors") or {}).get("total") or (m.get("gguf") or {}).get("total")
    return round(total / 1e6) if total else None


def flags(m):
    fs, tags, out = files(m), m.get("tags", []), []
    if "custom_code" in tags or any(f.endswith(".py") for f in fs):
        out.append("custom-code")
    if any(f.endswith(PICKLE) for f in fs) and not any(f.endswith((".safetensors", ".gguf", ".onnx")) for f in fs):
        out.append("pickle-only")
    if any(f.endswith(".gguf") for f in fs):
        out.append("gguf")
    if any(f.endswith(".onnx") for f in fs):
        out.append("onnx")
    if any(f.endswith(".safetensors") for f in fs):
        out.append("safetensors")
    if m.get("gated"):
        out.append("gated")
    if license_of(m).lower() not in OPEN_LICENSES:
        out.append("check-license")
    return out


def file_commit(repo, path):
    body = urllib.parse.urlencode({"paths": path, "expand": "true"}).encode()
    info = get(f"{API}/{repo}/paths-info/main", body)
    return info[0] if info else None


def check(registry):
    reg = json.load(open(registry))
    print("| model | repo | file | upstream commit | downloaded | status | license |")
    print("|---|---|---|---|---|---|---|")
    for e in reg.get("models", []):
        try:
            m, f = model(e["repo"]), file_commit(e["repo"], e["file"])
        except Exception as err:  # repo gone, renamed or private
            print(f"| {e['name']} | {e['repo']} | {e['file']} | ERROR {err} | | repo unreachable | |")
            continue
        if not f:
            status, date = "FILE MISSING upstream (renamed or removed?)", "-"
        else:
            date = ((f.get("lastCommit") or {}).get("date") or "")[:10]
            status = "UPDATED upstream" if date > e.get("downloaded", "") else "current"
        print(f"| {e['name']} | {e['repo']} | {e['file']} | {date} | {e.get('downloaded', '?')} | {status} | {license_of(m)} |")


def scan(registry, only=None):
    reg = json.load(open(registry))
    have = {e["repo"] for e in reg.get("models", [])}
    shortlisted = {c["repo"] for c in reg.get("candidates", [])}
    for role, spec in reg.get("roles", {}).items():
        if only and role != only:
            continue
        print(f"\n## {role}: {spec.get('need', '')}")
        print(f"placement {spec.get('placement')}, max {spec.get('maxParamsM')}M params, formats {spec.get('formats')}\n")
        print("| repo | params | updated | downloads | license | flags | note |")
        print("|---|---|---|---|---|---|---|")
        seen = set()
        for s in spec.get("searches", []):
            q = urllib.parse.urlencode({"limit": 30, **s})
            try:
                hits = get(f"{API}?{q}&{expand()}")
            except Exception as err:
                print(f"| search {s} failed: {err} | | | | | | |")
                continue
            for m in hits:
                repo = m["id"]
                if repo in seen:
                    continue
                seen.add(repo)
                p = params_m(m)
                if p and spec.get("maxParamsM") and p > spec["maxParamsM"]:
                    continue
                if any(x.lower() in repo.lower() for x in spec.get("exclude", [])):
                    continue
                if m.get("downloads", 0) < MIN_DOWNLOADS and not any(repo.startswith(o + "/") for o in spec.get("trusted", [])):
                    continue
                fl = flags(m)
                if spec.get("formats") and not any(f in fl for f in spec["formats"]):
                    continue
                note = "IN USE" if repo in have else ("shortlisted" if repo in shortlisted else "")
                print(f"| {repo} | {p or '?'}M | {m.get('lastModified', '')[:10]} | {m.get('downloads', 0)} | {license_of(m)} | {', '.join(fl)} | {note} |")


def info(repo, rev=None):
    m = model(repo)
    rev = rev or m.get("sha")
    fs = files(m)
    print(f"# {repo}\n")
    print(f"- revision: {rev} (pin this)")
    print(f"- updated: {m.get('lastModified', '')[:10]}, created: {m.get('createdAt', '')[:10]}, downloads: {m.get('downloads')}, likes: {m.get('likes')}")
    print(f"- task: {m.get('pipeline_tag')}, params: {params_m(m)}M, license: {license_of(m)}, flags: {', '.join(flags(m))}")
    print(f"- card: https://huggingface.co/{repo}/blob/{rev}/README.md")
    print(f"- weights: {', '.join(f for f in fs if f.endswith(WEIGHTS)) or 'none'}")
    code = [f for f in fs if f.endswith(".py")]
    for f in code:
        print(f"- code to review: https://huggingface.co/{repo}/blob/{rev}/{f}  (raw: https://huggingface.co/{repo}/raw/{rev}/{f})")
    cfg = next((f for f in fs if f == "config.json"), None)
    if cfg:
        print(f"- config: https://huggingface.co/{repo}/raw/{rev}/config.json (check auto_map and base model references)")


if __name__ == "__main__":
    cmd, args = (sys.argv[1], sys.argv[2:]) if len(sys.argv) > 1 else ("", [])
    if cmd == "check" and args:
        check(args[0])
    elif cmd == "scan" and args:
        scan(args[0], args[1] if len(args) > 1 else None)
    elif cmd == "info" and args:
        info(args[0], args[1] if len(args) > 1 else None)
    else:
        sys.exit(__doc__)
