---
description: Quick web answer: one lookup call (two at most), then a short sourced answer
---
Look this up: $@

1. Call `lookup` once with the question in full and a focused search query (add the
   year for anything current or versioned). It searches, reads the top pages and returns
   the passages that answer the question.
2. If the passages don't answer it, call `lookup` one more time with a different query.
   Don't fetch, grep or search any other way. Never more than two lookups.
3. Answer from the passages only, in at most ~150 words: the answer first, then any
   caveat that matters. End with **Sources:** the 1-3 URLs you used, with dates when shown.
   If the passages don't answer it, say so and give the closest thing found.
