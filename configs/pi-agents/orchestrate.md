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
3. **Plan the slices and show me.** Each slice fits a worker: one file, or a ~1500-line
   range, or one module. Say what each will find or change and where its output goes. List
   what you skip and why. Wait for my ok unless I said to go ahead.
4. **Run the workers** with the subagent tool in parallel mode, `cwd` set to the project
   folder, in waves of 2. Each brief is under 100 words and self-contained (the worker sees
   only the brief and the project's AGENTS.md): the exact path and range, what to find or
   do, "read in windows of 200 lines, grep first", the rules that matter, and "write your
   findings to <notes path>/<slice>.md with file:line references; end with open questions".
5. **Check after each wave.** Read the notes, not the sources. Spot-check a claim only when
   it matters or looks wrong (read those few lines yourself). Re-brief a slice that failed,
   once, with what was missing.
6. **Merge.** Write the final result yourself from the notes: what was found, with file:line
   references, what is uncertain, what was skipped. Then a one-line cost summary: waves,
   workers, slices redone.
