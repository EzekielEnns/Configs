---
description: Research a question with dig (search, read and quote-check pages in one call), then write one sourced answer
---
Research this: $@

The `dig` tool does the searching and reading: for each angle it searches, fetches the top
pages, has a reader list the facts on each page, and keeps only facts whose quote it found
on the page. You plan the angles and write the answer; don't search, fetch or read pages
yourself.

1. Run `date +%F` to get today's date.
2. Split the question into 2-3 angles that don't overlap, each a full question with 1-3
   search queries. Aim queries at primary sources (official docs, specs, release notes,
   repos) and add the year or "latest" for anything versioned.
3. Call `dig` once with all the angles (they run at the same time, about a minute).
4. Only if something the question needs is still missing, call `dig` once more with 1-2
   angles on exactly those gaps, with new queries. There is no third call.
5. Write the answer from dig's facts, at most ~500 words:
   - **Answer**: 2-4 sentences that directly answer the question as asked.
   - **Key points**: 5-8 bullets, most important first, merging repeats. Each ends with its
     source numbers, e.g. [2][5].
   - **Where to start**: if the question asks for links or how to build something, the
     3-5 best links in reading order, one line each on why.
   - **Uncertain**: 1-3 bullets, only real open questions or conflicts.
   - **Sources**: one list numbered 1..N, each a URL dig returned, with its date or version.
     Drop sources nothing cites.
   Use only dig's facts; prefer the newest source when they disagree. Start directly with
   **Answer**.
