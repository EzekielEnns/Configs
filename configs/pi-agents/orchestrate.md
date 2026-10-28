---
description: Plan a code-reading job as a ledger of slices, run reader workers on Flint with pi-orch, and merge their checked claims
---
Goal: $@

You plan and merge. `reader` workers on Flint do the reading, and `pi-orch` (a script, not a
model) runs them 2 at a time, checks every claim's quote against its file, and retries a
slice once. Then a gap pass: the lines no claim covered are ranked against the goal and the
best go to one more worker per slice (slice `<id>g`). You never brief workers yourself: the
brief comes from a fixed template.

1. **Orient (small, about a minute).** The project's AGENTS.md / README, then ls and `wc -l`;
   grep only to find where something the goal names lives. Don't read the code itself: that
   is the workers' job, and you'll get it back as checked claims. Stay in the project folder:
   pi-orch is on PATH, and other runs' notes aren't yours to read.
2. **Write the ledger.** Notes go in `~/.pi/orch/<short-name>/` unless I name a folder.
   Write `<notes>/ledger.json`:
   `{"goal": "...", "focus": "...", "root": "<project path>", "slices": [{"id": "s1", "file": "src/x.rs", "lines": [1, 400], "questions": ["..."]}]}`
   `focus` is one sentence on what counts as relevant code for this goal (e.g. "lines that set
   a limit or default, or decide when a call is refused"); the gap pass ranks lines by it.
   One file per slice, at most 600 lines. A file that fits is one slice: the worker gets the
   lines in its prompt and answers in one turn (about a minute), 2 at a time, so fewer slices
   finish sooner.
   1-4 questions per slice, each answerable by a line of code (a call, a name, a constant),
   e.g. "Which function does the POST /search route call?" Then run
   `pi-orch check <notes>/ledger.json` and fix what it reports.
3. **Show me the plan:** `pi-orch status <notes>/ledger.json`, plus what you skip and why.
   Wait for my ok unless I said to go ahead.
4. **Run:** `pi-orch run <notes>/ledger.json`. It prints a line per try, about a minute
   per slice, then the gap pass. After it starts, don't change slices' status except to set
   a failed one to `redo` (with better questions).
5. **Read `<notes>/digest.md` in one read** (run writes it; `pi-orch digest` rewrites it). Its
   claims are verified (checkrefs found each quote in the file), so use them without
   re-reading the code. Only for a claim marked `[far]` or `[numbers ...]`, read those few
   lines yourself. The gap pass has already re-read what the first pass skipped, so don't run
   another round; only if the goal needs a file no slice covered, add it as a `pending`
   slice and run once more.
6. **Merge.** Write the answer from the digest to `<notes>/report.md` and reply with it:
   every claim that answers the goal, with its values and file:line; what's uncertain; what
   was skipped. End with one line from `pi-orch status`: slices, tries, verified / dropped claims.
