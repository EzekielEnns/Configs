---
description: Plan a code-reading job as a ledger of slices, run reader workers on Flint with pi-orch, and merge their checked claims
---
Goal: $@

You plan and merge. `reader` workers on Flint do the reading, and `pi-orch` (a script, not a
model) runs them 2 at a time, checks every claim's quote against its file, and retries a
slice once. You never brief workers yourself: the brief comes from a fixed template.

1. **Orient (small).** The project's AGENTS.md / README, then ls, `wc -l`, and grep for the
   entry points and names the goal mentions. Don't read whole files; keep your own raw
   reading under ~200 lines per file.
2. **Write the ledger.** Notes go in `~/.pi/orch/<short-name>/` unless I name a folder.
   Write `<notes>/ledger.json`:
   `{"goal": "...", "root": "<project path>", "slices": [{"id": "s1", "file": "src/x.rs", "lines": [1, 400], "questions": ["..."]}]}`
   One file per slice, at most 600 lines. A file that fits is one slice: the worker gets the
   lines in its prompt and answers in one turn (about a minute), 2 at a time, so fewer slices
   finish sooner.
   1-4 questions per slice, each answerable by a line of code (a call, a name, a constant),
   e.g. "Which function does the POST /search route call?" Then run
   `pi-orch check <notes>/ledger.json` and fix what it reports.
3. **Show me the plan:** `pi-orch status <notes>/ledger.json`, plus what you skip and why.
   Wait for my ok unless I said to go ahead.
4. **Run:** `pi-orch run <notes>/ledger.json`. It prints a line per try, about a minute
   per slice. After it starts, don't change slices' status except to set a failed
   one to `redo` (with better questions); you may add new slices as `pending`.
5. **Read `<notes>/digest.md`** (run writes it; `pi-orch digest` rewrites it). It holds only
   claims whose quote was found in the file. Before using a claim marked `[far]` or
   `[numbers ...]`, read those few lines yourself. If a step of the answer is missing, add a
   slice for it (the workers' open questions often name where) and run again; one more
   round at most.
6. **Merge.** Write the answer from the digest to `<notes>/report.md` and reply with it:
   each point with file:line, what's uncertain, what was skipped. End with one line from
   `pi-orch status`: slices, tries, verified / dropped claims.
