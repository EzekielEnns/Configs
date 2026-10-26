# Plan: LSP tools for one Pi agent

Goal: give one Pi agent (a `coder` agent) language-server tools — go to definition,
find references, diagnostics, hover, rename — using the same language servers Neovim
already uses, picked per project. Ordinary Pi runs (the main session, researchers,
scouts) should not pay for these tools in context.

Status (2026-10-26): planned, not built. Pi 1.4 (`configs/agents.nix`) has built-in MCP,
which is what this hangs off.

## Decision: agent-lsp

| | [agent-lsp](https://github.com/blackwell-systems/agent-lsp) | [mcp-language-server](https://github.com/isaacphi/mcp-language-server) |
| --- | --- | --- |
| Latest | v0.23.2, 2026-10-26; releases every few days | v0.1.1, May 2025; PRs from Jul–Sep 2026 unmerged |
| Open issues | 12 | 71 (basedpyright returns nothing, TS breakage, fd leak) |
| Languages | many in one process, routed by file extension | one LSP per process |
| Tools | 65 (plus skills as MCP prompts) | 6 |
| Detection | none; `agent-lsp init` finds servers on PATH | none; you name `--lsp` |
| Build | Go 1.26 | Go 1.24 |

agent-lsp is maintained and handles several languages at once. It keeps a daemon
running (exits after 30 min idle), so sub-agents shouldn't each re-index the project.
Its 65 tools are the cost, which the exposure settings below deal with. These facts come
from the READMEs and issue trackers, not from running either one.

## Design

1. **Package agent-lsp** with `buildGoModule` from the `pi-nixpkgs` pin (it has Go
   1.26.10; our stable pin may not). Probably `doCheck = false`: its tests want real
   language servers.

2. **`pi-lsp` wrapper** (`writeShellScriptBin`). Looks at the project root for markers
   and execs agent-lsp with `lang:binary,args` for only the servers that match. No
   Neovim integration: same binaries, found the same way (on PATH, from the packages in
   `modules/nvim.nix`).

   | Marker | Server (Neovim name) | Binary / source |
   | --- | --- | --- |
   | `go.mod` | `gopls` | NixOS: `pkgs-unstable.gopls`; macOS: `go-tools-install` (Go lives outside Nix there) |
   | `pyproject.toml`, `setup.py`, `requirements.txt` | `basedpyright`, `ruff` | `basedpyright-langserver --stdio`, `ruff server` |
   | `Cargo.toml` | `rust_analyzer` | `rust-analyzer` from `rustup` (not a Nix package) |
   | `package.json`, `tsconfig.json` | TypeScript (Neovim uses typescript-tools.nvim) | `typescript-language-server --stdio` (in `nvim.nix`) |
   | `.luarc.json`, `*.lua` | `lua_ls` | `lua-language-server` |
   | `*.tf` | `terraformls` | `terraform-ls serve` |

   Other servers Neovim enables (`vim.lsp.enable` in `nvim/lua/plugins/lspconfig.lua`):
   `gdscript`, `golangci_lint_ls`, `efm`, `cssls`, `html`, `eslint`, `jsonls`,
   `tailwindcss`, `mdx_analyzer`, `roslyn_ls`. Add them only if agent-lsp supports them
   and an agent would use them; formatters/linters (`efm`, `golangci_lint_ls`) probably
   aren't worth it. There is no Nix LSP (nil/nixd) installed today.

3. **Pi MCP config**, generated in `configs/agents.nix` into `~/.pi/agent/mcp.json`:
   - server `lsp`, command `pi-lsp`, a one-line `description`
   - `exposure: "deferred"` — per Pi's `docs/mcp.md`, deferred tools aren't declared to
     the model until `tool_search` loads them; other agents only see the server's line in
     the system prompt
   - `toolExposure` making ~5 tools `direct`: references, definition, diagnostics,
     hover, rename (confirm agent-lsp's exact names, e.g. `find_references`,
     `get_diagnostics`, when packaging)

4. **`coder` agent** in `configs/pi-agents/`, wired like `researcher`/`architect`, whose
   `tools:` list includes the LSP tools plus read/edit/bash. Maybe give `worker` and
   `reviewer` diagnostics later.

## Open questions

- Does Pi's `--tools` flag (the subagent extension passes the agent's `tools:` that way)
  accept `mcp__lsp__*` names? If not, scope by giving the coder agent its own MCP config.
- agent-lsp's exact tool names and how much context the direct ones cost.
- How agent-lsp picks the workspace root (the wrapper may need to pass it).
- Support for ruff, tailwind, golangci-lint; Python/TypeScript need minutes of indexing
  before references work (per its README).
- Pi starts configured MCP servers for every process, sub-agents included; check the
  daemon is reused and startup doesn't slow every run.
- Both hosts run `agents.nix`: gopls and rust-analyzer come from outside Nix on macOS,
  so the wrapper must find them on PATH rather than hard-coding store paths.

## Steps

- [ ] Package agent-lsp; check `agent-lsp --help` and its tool list.
- [ ] Write `pi-lsp`; test marker detection by hand in a Go and a Python repo.
- [ ] Add `mcp.json` (deferred + direct tools) to `agents.nix`; check with `pi mcp list`.
- [ ] Check whether `--tools` accepts MCP tool names.
- [ ] Add the `coder` agent.
- [ ] Test: in a Go repo, ask the coder agent for the references of a function and compare
      with `grep`; break a file and ask for diagnostics; rename a symbol.
- [ ] Confirm other agents' context didn't grow (`/mcp` shows exposure).

## Sources

- https://github.com/blackwell-systems/agent-lsp
- https://github.com/isaacphi/mcp-language-server
- Pi MCP docs: `$(dirname $(dirname $(readlink -f $(which pi))))/lib/node_modules/pi-monorepo/docs/mcp.md`
