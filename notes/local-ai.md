# Local AI stack

Moved to its own repo: `~/Documents/repos/ai-stack` (plan in `docs/PLAN.md`).
The desktop imports it as a flake input; Mac-side harness config stays here.

## poi: points of interest

`poi` (configs/poi) asks Jev, through the desktop gateway, how much each block bears on a question
and prints a jump list, grouped by file, best first. Code is cut with tree-sitter (a headless
Neovim with poi's own Nix parsers): whole functions, classes and Nix bindings, each sent with its
symbol chain and the file's imports. It ranks files first (path + outline), then the blocks of the
top 20. On this repo: about 200-350 Jev requests, 7-14 s, $0.005-0.011 (was 620 blocks, 23 s,
$0.015 with fixed 12-line windows).

    poi "where is compaction configured" configs     # code or docs under paths (default .)
    poi --diff                                       # hunks of the working tree vs HEAD
    poi --diff main...HEAD "auth or token handling"  # a branch, with a focus
    poi --diff main...HEAD --flow                    # PR review in call order
    poi "how pis starts a job" configs --flow --tour # call order + Flint's notes per step
    poi "how do I allow writes" https://...          # passages of a page, with #:~:text= links

- `--follow`: callers of the top 5 hits (language server when installed, else `rg -w`).
- `--tour`: Flint writes a guided read over the hits (30-75 s on the desktop GPU, free); stops
  citing anything outside the hits are dropped. agents-a1-4b was tried: slower and twice gave
  nothing (it spent the whole output budget thinking).
- `--flow`: hits become functions, ordered depth-first from the entry points along call edges
  (language-server call hierarchy, else calls/mentions in the text, else line order for top-level
  script code). Steps with no edge are marked "order unknown"; with `--tour`, Flint places them.
- `--qf`: quickfix lines, `poi --qf "q" | nvim -q -`. `--open`: a Rex pane to the right running
  `nvim -c 'PoiLoad …'` (outside Rex it prints the commands). `--json`: one line, paths relative
  to "root", with the cost; about 350-750 tokens for 15 hits, ~1.2k with --flow --tour.
- In Neovim (nvim/lua/poi.lua): `:Poi q`, `:PoiFlow q`, `:Poi! [ref] [focus]` (diff), `:PoiLoad
  file.json`, `:PoiLast`; `<leader>ii` / `it` (tour) / `if` (flow) / `id` (diff review) / `il`.
  Results go to the quickfix list (]q, [q, Trouble qflist) and a snacks picker with preview.
- Terminal output links each `path:line` (OSC 8, `nvim-open://`) when stdout is a terminal.
- `-n N` / `--all`, `--files K`, `--flat`; over 600 Jev requests it asks for `--yes`. Files that
  look like secrets (.env*, *.pem, *key*, auth.json, secrets*) are never sent.
- Testing without Jev: `POI_JEV_STUB=1` (word-overlap scores), `POI_JEV_CACHE=file` (reuse answers).
