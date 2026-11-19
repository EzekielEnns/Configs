"""imagegen: game-asset and 3D-modeling reference images through OpenRouter.

    imagegen "a dwarf blacksmith with brass gauntlets"                # lowpoly, single
    imagegen -s lowpoly -k turnaround "the blacksmith" -r smith.png   # front/side/back sheet
    imagegen -k lineup -n 3 -f townsfolk.txt                          # 3 variations
    imagegen -m gpt -a 16:9 "tavern interior, modular kit pieces"
    imagegen --dry-run -k props "potions, scrolls, a lantern"         # print the prompt only

Prompt = style + sheet layout + your subject. Reference images (-r) are sent along and the
model is told to match their style, so a picture you like becomes the style for the next batch.

Where requests go:
  - OPENROUTER_API_KEY set: straight to OpenRouter.
  - otherwise: the desktop gateway's /openrouter/chat pass-through (ai-stack), which adds the
    key there, so the Mac never holds it. IMAGEGEN_URL overrides the address.

Each image is saved as PNG next to a .json with the full prompt, model, refs and cost, so a
good result can be reproduced or used as the next reference.
"""

import argparse
import base64
import concurrent.futures as cf
import datetime as dt
import json
import mimetypes
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

# Short names for the models worth using. Any full OpenRouter id also works with -m.
# modalities: image-only models reject "text" in the output list.
MODELS = {
    "grok": ("x-ai/grok-imagine-image-2.0", ["image"]),
    "gpt": ("openai/gpt-image-2", ["image"]),
    "nano": ("google/gemini-nano-banana-2.1", ["image", "text"]),
    "gemini-pro": ("google/gemini-3-pro-image", ["image", "text"]),
    "seedream": ("bytedance-seed/seedream-5-0-pro", ["image"]),
    "flux": ("black-forest-labs/flux-3-image", ["image"]),
}
DEFAULT_MODEL = os.environ.get("IMAGEGEN_MODEL", "grok")

# Rendering style. Edit freely; these are the whole "house style".
STYLES = {
    "lowpoly": (
        "Stylized low-poly 3D game art render: faceted flat-shaded polygons with visible facets, "
        "soft muted pastel palette, clean stylized faces with expressive eyes, chunky readable "
        "proportions, soft studio lighting from the upper left, subtle contact shadow, "
        "plain light grey background, no text or labels."
    ),
    "handpainted": (
        "Stylized 3D game character with hand-painted textures, painterly shading baked into "
        "the albedo, slightly exaggerated proportions, warm saturated palette, soft lighting, "
        "plain light grey background, no text or labels."
    ),
    "toon": (
        "Cel-shaded 3D toon render: flat colour bands, crisp dark outlines, bright clean palette, "
        "simple shapes, plain white background, no text or labels."
    ),
    "pbr": (
        "Realistic PBR game asset render in the style of a modern AAA asset viewer: physically "
        "based materials, neutral studio HDRI lighting, plain mid-grey background, no text or labels."
    ),
    "voxel": (
        "Voxel art 3D render: everything built from small uniform cubes, bright palette, soft "
        "ambient occlusion, plain light background, no text or labels."
    ),
    "none": "",
}

# Layout. {subject} is replaced with your text; a sheet without it gets the subject appended.
SHEETS = {
    "single": (
        "A single subject, full body and fully in frame, centered, front three-quarter view, "
        "relaxed standing pose: {subject}"
    ),
    "lineup": (
        "A lineup of different characters standing side by side at correct relative scale, "
        "front three-quarter view, relaxed standing poses, each with a clearly different "
        "silhouette, age and body type, all fully in frame and evenly spaced: {subject}"
    ),
    "turnaround": (
        "Character turnaround reference sheet for 3D modeling. The SAME character shown four "
        "times side by side: front view, left side profile, back view, and front three-quarter "
        "view. Neutral A-pose with arms slightly away from the body, orthographic camera, "
        "identical proportions, height and details in every view, all feet on one ground line, "
        "flat even lighting, no perspective distortion. Character: {subject}"
    ),
    "expressions": (
        "Facial expression sheet: the SAME character's head and shoulders shown in a 3x2 grid, "
        "neutral, happy, angry, sad, surprised and smug, identical design in each: {subject}"
    ),
    "props": (
        "Game asset prop sheet: separate isolated props arranged in a clean grid, each fully "
        "visible with space around it, no overlap, consistent scale and lighting, three-quarter "
        "top-down view: {subject}"
    ),
    "kit": (
        "Modular environment kit sheet for a 3D level: separate isolated pieces (walls, floors, "
        "corners, doors, trims) in a clean grid, isometric view, consistent scale: {subject}"
    ),
    "scene": (
        "Environment concept for a game level, readable layout and clear focal point, "
        "three-quarter elevated camera: {subject}"
    ),
}

REF_NOTE = (
    "Match the art style, rendering, face style and colour palette of the attached reference "
    "image(s) exactly; use them for style, not for content unless asked."
)


def compose(style: str, sheet: str, subject: str, refs: bool, extra: str) -> str:
    layout = SHEETS[sheet]
    body = layout.replace("{subject}", subject) if "{subject}" in layout else f"{layout} {subject}"
    parts = [REF_NOTE if refs else "", STYLES[style], body, extra]
    return "\n\n".join(p.strip() for p in parts if p and p.strip())


def data_url(path: Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "image/png"
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode()}"


def endpoint() -> tuple[str, dict]:
    key = os.environ.get("OPENROUTER_API_KEY")
    if key:
        url = "https://openrouter.ai/api/v1/chat/completions"
        auth = key
    else:
        url = os.environ.get("IMAGEGEN_URL", "http://desktop:4000/openrouter/chat")
        auth = os.environ.get("IMAGEGEN_GATEWAY_KEY", "local")
    headers = {
        "Authorization": f"Bearer {auth}",
        "Content-Type": "application/json",
        "X-Title": "imagegen",
    }
    return url, headers


def request(model: str, modalities: list, prompt: str, refs: list[Path], aspect: str | None) -> dict:
    content = [{"type": "text", "text": prompt}]
    content += [{"type": "image_url", "image_url": {"url": data_url(r)}} for r in refs]
    body = {
        "model": model,
        "messages": [{"role": "user", "content": content}],
        "modalities": modalities,
        "usage": {"include": True},
    }
    if aspect:
        body["image_config"] = {"aspect_ratio": aspect}
    url, headers = endpoint()
    req = urllib.request.Request(url, json.dumps(body).encode(), headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:800]
        raise SystemExit(f"imagegen: HTTP {e.code} from {url}\n{detail}") from None
    except urllib.error.URLError as e:
        hint = "" if "openrouter.ai" in url else (
            "\n(is the gateway's /openrouter/chat pass-through deployed? or set OPENROUTER_API_KEY)"
        )
        raise SystemExit(f"imagegen: can't reach {url}: {e.reason}{hint}") from None


def images_from(resp: dict) -> list[bytes]:
    out = []
    for choice in resp.get("choices", []):
        for img in (choice.get("message") or {}).get("images") or []:
            url = (img.get("image_url") or {}).get("url", "")
            if url.startswith("data:"):
                out.append(base64.b64decode(url.split(",", 1)[1]))
            elif url.startswith("http"):
                with urllib.request.urlopen(url, timeout=120) as r:
                    out.append(r.read())
    return out


def slugify(text: str, n: int = 40) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:n].rstrip("-") or "image"


def main() -> None:
    ap = argparse.ArgumentParser(
        prog="imagegen",
        description="Game-asset / 3D reference images via OpenRouter.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="styles: " + ", ".join(STYLES) + "\nsheets: " + ", ".join(SHEETS)
        + "\nmodels: " + ", ".join(f"{k} ({v[0]})" for k, v in MODELS.items()),
    )
    ap.add_argument("subject", nargs="*", help="what to draw")
    ap.add_argument("-f", "--file", type=Path, help="read the subject from a file (long lists)")
    ap.add_argument("-s", "--style", default=os.environ.get("IMAGEGEN_STYLE", "lowpoly"), choices=STYLES)
    ap.add_argument("-k", "--sheet", default="single", choices=SHEETS, help="layout")
    ap.add_argument("-m", "--model", default=DEFAULT_MODEL, help="alias or full OpenRouter id")
    ap.add_argument("-r", "--ref", type=Path, action="append", default=[], help="style reference image (repeatable)")
    ap.add_argument("-a", "--aspect", help="aspect ratio, e.g. 16:9, 1:1, 3:4 (if the model supports it)")
    ap.add_argument("-n", type=int, default=1, help="number of variations (run in parallel)")
    ap.add_argument("-x", "--extra", default="", help="extra instructions appended to the prompt")
    ap.add_argument("-o", "--out", type=Path, default=Path(os.environ.get("IMAGEGEN_OUT", "art-refs")))
    ap.add_argument("--raw", action="store_true", help="send the subject as-is, no style or sheet")
    ap.add_argument("--dry-run", action="store_true", help="print the prompt and exit")
    ap.add_argument("--open", action="store_true", help="open the results when done")
    a = ap.parse_args()

    subject = " ".join(a.subject).strip()
    if a.file:
        subject = (subject + "\n" + a.file.read_text()).strip()
    if not subject:
        ap.error("give a subject, or -f FILE")
    for r in a.ref:
        if not r.is_file():
            ap.error(f"reference not found: {r}")

    model, modalities = MODELS.get(a.model, (a.model, ["image", "text"]))
    prompt = subject if a.raw else compose(a.style, a.sheet, subject, bool(a.ref), a.extra)

    if a.dry_run:
        print(f"model: {model}  modalities: {modalities}  refs: {[str(r) for r in a.ref]}\n")
        print(prompt)
        return

    a.out.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    base = f"{stamp}-{a.sheet}-{slugify(a.subject and ' '.join(a.subject) or (a.file.stem if a.file else subject))}"
    print(f"imagegen: {a.n} x {model} ({a.style}/{a.sheet}) -> {a.out}/", file=sys.stderr)

    with cf.ThreadPoolExecutor(max_workers=min(a.n, 6)) as pool:
        futures = [pool.submit(request, model, modalities, prompt, a.ref, a.aspect) for _ in range(a.n)]
        results = [f.result() for f in futures]

    saved, total_cost = [], 0.0
    for i, resp in enumerate(results, 1):
        imgs = images_from(resp)
        cost = (resp.get("usage") or {}).get("cost") or 0
        total_cost += cost
        if not imgs:
            msg = (resp.get("choices") or [{}])[0].get("message", {}).get("content")
            print(f"imagegen: request {i} returned no image. {msg or json.dumps(resp)[:500]}", file=sys.stderr)
            continue
        for j, png in enumerate(imgs, 1):
            name = f"{base}-{i}" + (f"-{j}" if len(imgs) > 1 else "")
            path = a.out / f"{name}.png"
            path.write_bytes(png)
            (a.out / f"{name}.json").write_text(json.dumps({
                "model": model, "style": a.style, "sheet": a.sheet, "subject": subject,
                "extra": a.extra, "aspect": a.aspect, "refs": [str(r) for r in a.ref],
                "prompt": prompt, "cost_usd": cost, "created": stamp,
            }, indent=2))
            saved.append(path)
            print(path)

    print(f"imagegen: {len(saved)} image(s), ${total_cost:.4f}", file=sys.stderr)
    if a.open and saved and sys.platform == "darwin":
        subprocess.run(["open", *map(str, saved)])
    if not saved:
        sys.exit(1)


if __name__ == "__main__":
    main()
