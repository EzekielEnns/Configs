"""Grocery-list photos to checklist notes (desktop; modules/notes-sync.nix runs it).

A photo dropped in the vault's Inbox/Groceries/ (from a phone, through Syncthing) becomes
Shared/Groceries/<date>.md: one `- [ ]` per item; the photo is deleted once the note is
written (the phone's camera roll still has it). Bolt reads the
handwriting (through llama-swap, which loads it if another model is on the GPU) and answers
in a fixed JSON schema; this script writes the Markdown, so the format never drifts.

A photo that fails moves to Inbox/Groceries-failed/ (outside the watched folder, so it isn't
retried in a loop); move it back to try again.

Usage: groceries.py VAULT API_URL MODEL MAGICK
"""
import base64
import datetime
import json
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

IMAGES = {".jpg", ".jpeg", ".png", ".webp"}
SETTLE = 3  # seconds a file must be unchanged, in case a writer isn't done

PROMPT = """This is a photo of a handwritten grocery list. List every item on it, in order, as written.
- One entry per item: when a line names several things separated by commas, give each its own entry.
- Keep quantities and notes that belong to an item with it ("2 milk", "eggs (dozen)").
- Include every column, and small additions squeezed between or above lines.
- Skip headings, dates and crossed-out items.
- If you can't read an item with confidence, give your best guess and set unsure to true.
- If the photo isn't a list, return no items."""
# Bolt sometimes slips into Gemma 4's thinking channel even with thinking off and loops there
# until the token limit, leaving no answer (a 25-line list did). So: answer directly first,
# and if that comes back empty or broken, once more with thinking allowed, which ends cleanly.
SYSTEM = "Answer directly with the JSON. Do not think out loud."

SCHEMA = {
    "type": "object",
    "properties": {
        "items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {"text": {"type": "string"}, "unsure": {"type": "boolean"}},
                "required": ["text", "unsure"],
            },
        }
    },
    "required": ["items"],
}


def read_list(photo: Path, api: str, model: str, magick: str) -> list[dict]:
    # Phones store the camera's rotation in EXIF, which the model's image loader ignores:
    # turn the pixels upright, and shrink it (the vision encoder downsizes anyway).
    with tempfile.TemporaryDirectory() as tmp:
        jpg = Path(tmp) / "list.jpg"
        subprocess.run([magick, str(photo), "-auto-orient", "-resize", "1600x1600>", "-quality", "90", str(jpg)],
                       check=True, capture_output=True)
        data = base64.b64encode(jpg.read_bytes()).decode()
    user = {"role": "user", "content": [
        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{data}"}},
        {"type": "text", "text": PROMPT},
    ]}
    for think in (False, True):
        body = {
            "model": model,
            "temperature": 0.2,
            "max_tokens": 6144,
            "chat_template_kwargs": {"enable_thinking": think},
            "response_format": {"type": "json_schema", "json_schema": {"name": "groceries", "schema": SCHEMA}},
            "messages": [user] if think else [{"role": "system", "content": SYSTEM}, user],
        }
        req = urllib.request.Request(f"{api}/chat/completions", json.dumps(body).encode(),
                                     {"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=600) as resp:  # a cold model load takes a while
            reply = json.load(resp)
        try:
            items = json.loads(reply["choices"][0]["message"]["content"])["items"]
            return [i for i in items if i["text"].strip()]
        except (ValueError, KeyError, TypeError):
            if think:
                raise
            print("no answer without thinking; retrying with it", file=sys.stderr)
    raise AssertionError("unreachable")


def free(path: Path) -> Path:
    """path, or path with -2, -3, ... before the suffix if it's taken."""
    n, candidate = 1, path
    while candidate.exists():
        n += 1
        candidate = path.with_name(f"{path.stem}-{n}{path.suffix}")
    return candidate


def main() -> None:
    vault, api, model, magick = Path(sys.argv[1]), sys.argv[2].rstrip("/"), sys.argv[3], sys.argv[4]
    inbox = vault / "Inbox" / "Groceries"
    out = vault / "Shared" / "Groceries"
    failed = vault / "Inbox" / "Groceries-failed"
    inbox.mkdir(parents=True, exist_ok=True)

    photos = sorted((p for p in inbox.iterdir()
                     if p.is_file() and p.suffix.lower() in IMAGES and not p.name.startswith(".")),
                    key=lambda p: p.stat().st_mtime)
    for photo in photos:
        if time.time() - photo.stat().st_mtime < SETTLE:
            time.sleep(SETTLE)
        taken = datetime.datetime.fromtimestamp(photo.stat().st_mtime)
        try:
            items = read_list(photo, api, model, magick)
        except Exception as e:  # noqa: BLE001 - any failure parks the photo, the rest go on
            failed.mkdir(parents=True, exist_ok=True)
            shutil.move(photo, free(failed / photo.name))
            print(f"{photo.name}: failed ({e}); moved to {failed}", file=sys.stderr)
            continue

        out.mkdir(parents=True, exist_ok=True)
        note = free(out / f"{taken:%Y-%m-%d}.md")
        lines = ["---", "tags:", "  - groceries", f"created: {taken:%Y-%m-%dT%H:%M}", "---", ""]
        lines += [f"- [ ] {i['text'].strip()}" + (" (?)" if i["unsure"] else "") for i in items]
        if not items:
            lines.append("_No items read from the photo._")
        lines.append("")
        note.write_text("\n".join(lines))
        photo.unlink()
        print(f"{photo.name}: {len(items)} items -> {note.relative_to(vault)}")


if __name__ == "__main__":
    main()
