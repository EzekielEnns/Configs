---
description: Research, design with questions for the user, then build in parallel and review
---
Goal: $@

Phase 1, research: split the goal into 2-3 research angles (prior art, libraries or APIs,
pitfalls) and run one "researcher" per angle in parallel with the subagent tool.

Phase 2, design: run the "architect" agent with the goal and all research notes. If we're
in an existing project, tell it to read the relevant code first.

Phase 3, stop and ask: show me the architect's Recommendation, Build plan and
"Questions for you". Then STOP and wait for my answers. Do not build anything yet.

Phase 4, build (only after I answer): update the plan with my answers, then run "worker"
agents in parallel on the independent steps (one per file/module boundary), and the
dependent steps after them. Each worker gets the design, its step, and my answers.

Phase 5, review: run the "reviewer" agent on the result against the design. Fix what it
finds with a worker, run the tests, and give me a short summary of what was built.
