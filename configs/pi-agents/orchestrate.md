---
description: Plan a big job and run it with worker subagents on Flint; you only plan, check and merge
---
Goal: $@

You are the orchestrator, on a strong model with a big context. The workers are `worker`
subagents on Flint (local, free, 32k context, at most 2 run at once). Your job is to plan,
brief, check and merge; theirs is the bulk reading and writing.

1. **Orient (small).** Read the project's AGENTS.md / README if present, then look at the
   shape of the work with ls, sizes, `head`, grep. Don't read whole files.
2. **Do the hard one-off steps yourself**, the ones every worker depends on and Flint would
   get wrong: a decoder, a shared script in the project's tools folder, the slice plan.
   Keep your own raw reading under ~200 lines per file. Past a budget, a "Pi delegation
   guard" note replaces big tool output: it comes from the harness, so delegate that read.
3. **Plan the slices and show me.** Each slice fits a worker: one small file, a 600-800
   line range, or one module. A worker has 32k of context and 40 tool calls, and reads 80
   lines at a time, so smaller is better. Say what each will find or change and where its output goes. List
   what you skip and why. Wait for my ok unless I said to go ahead.
4. **Run the workers** with the subagent tool in parallel mode, `cwd` set to the project
   folder, 2 per call (up to 24 per prompt). Each brief is under 100 words and
   self-contained (the worker sees only the brief and the project's AGENTS.md): the exact
   path and range, what to find or do, the rules that matter, and these lines verbatim:
   "grep for what you need first, then read only those spots. Your deliverable is the file
   <notes path>/<slice>.md: write it after your first few findings and rewrite it as you go,
   with file:line for each claim and open questions at the end. Your final reply is just
   that path and 3 lines of summary." The file survives a worker that runs out of room.
5. **Check after each wave.** Read the notes files, not the sources. A worker that stopped
   early still leaves its file; brief the rest of its range as a new slice. Spot-check a claim only when
   it matters or looks wrong (read those few lines yourself). Re-brief a slice that failed,
   once, with what was missing.
6. **Merge.** Write the final result yourself from the notes: what was found, with file:line
   references, what is uncertain, what was skipped. Then a one-line cost summary: waves,
   workers, slices redone.
