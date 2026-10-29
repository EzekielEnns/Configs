# Local AI stack

Moved to its own repo: `~/Documents/repos/ai-stack` (plan in `docs/PLAN.md`).
The desktop imports it as a flake input; Mac-side harness config stays here.

## poi: points of interest

`poi` (configs/poi) asks Jev, through the desktop gateway, how much each block bears on a question
and prints a jump list, best first. About $0.015 and 25 s for ~600 blocks.

    poi "where is compaction configured" configs     # code or docs under paths (default .)
    poi --diff                                       # hunks of the working tree vs HEAD
    poi --diff main...HEAD "auth or token handling"  # a branch, with a focus
    poi "how do I allow writes" https://...          # passages of a page, with #:~:text= links

`-n N` / `--all`, `--json`; over 500 blocks it asks for `--yes`. Files that look like secrets
(.env*, *.pem, *key*, auth.json, secrets*) are never sent.
