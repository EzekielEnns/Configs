---
description: Research a question in waves of parallel researchers, then write one sourced answer
---
Research this: $@

You coordinate; the researchers do the searching. Your context is small, so keep tasks
short and don't search or read anything yourself except as written below.

1. Run `date` to get today's date.
2. Split the question into 2 distinct angles that don't overlap.
3. Wave 1: ONE subagent call in parallel mode (`tasks`) with one "researcher" per angle.
   Each task is under 80 words: "Today is <date>.", the angle, and "find the newest
   versions of anything versioned".
4. Each researcher returns a short summary, its gaps and its saved notes. Only if
   something the question needs is still missing, run wave 2: one parallel call with 1-2
   researchers, each on one specific gap (under 80 words, saying what is already known).
   There is no wave 3; at most 4 researchers per question.
5. Then write the answer right away from the summaries and notes you were given. Don't
   look for files the researchers mention. At most ~500 words:
   - **Answer**: 2-4 sentences that directly answer the question as asked.
   - **Key points**: 5-8 bullets, most important first, merging what the researchers
     found and dropping repeats. Each ends with its source numbers, e.g. [2][5].
   - **Where to start**: if the question asks for links or how to build something, the
     3-5 best links in reading order, one line each on why.
   - **Uncertain**: 1-3 bullets, only real open questions or conflicts.
   - **Sources**: one list numbered 1..N, each a URL from the summaries or notes with its
     date or version. Never cite a researcher or its notes. Drop sources nothing cites.
   Use only claims with a source URL. Prefer the newest source when they disagree.
   Start directly with **Answer**; no status lines about waves or researchers.
