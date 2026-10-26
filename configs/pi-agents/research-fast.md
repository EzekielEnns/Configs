---
description: Like /research, but 3-4 fast researchers in parallel on the small research model
---
Research this: $@

1. Run `date` to get today's date.
2. Split the question into 3-4 distinct angles that don't overlap.
3. Use the subagent tool to run one "researcher-fast" per angle, in parallel. Start each task
   with "Today is <date>." and ask for the newest versions of anything versioned.
4. Write ONE combined answer, not one section per angle. At most ~500 words:
   - **Answer**: 2-4 sentences that directly answer the question as asked.
   - **Key points**: 5-8 bullets, most important first, merging what the researchers
     found and dropping repeats. Each ends with its source numbers, e.g. [2][5].
   - **Where to start**: if the question asks for links or how to build something, the
     3-5 best links in reading order, one line each on why.
   - **Uncertain**: 1-3 bullets, only real open questions or conflicts.
   - **Sources**: one list numbered 1..N across all researchers, with dates. Renumber
     the researchers' citations to match it, and drop sources nothing cites.
   Use only claims the researchers sourced. Prefer the newest source when they disagree.
