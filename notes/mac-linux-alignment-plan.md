# Plan: align the NixOS desktop shell/home config with the macbook

Goal: make the NixOS desktop (`#desktop`) interactive experience match the
macbook (`#macbook`) so changes don't have to be made twice and the two machines
feel the same.

## Current state (2026-10-23)

Already shared via `configs/*` and consistent on both hosts:
starship (prompt), git (`configs/git.nix` — on Linux via `configs/users.nix`),
tmux, nvim, `files` (dotfiles incl. ghostty + mpv), direnv, fzf.

What drifts — `modules/home.nix` (NixOS) is a strict subset of
`darwin/home.nix` (mac):

| home-manager piece | macbook | NixOS desktop |
| --- | --- | --- |
| starship / git / files / tmux | yes | yes |
| shell | zsh (`programs.zsh`) | bash (`misc/.bashrc`) |
| `claude.nix` (Claude Code cfg) | yes | no |
| `rex.nix` (rex terminal cfg) | yes | no |
| `home.sessionPath` (`.local/bin`, `go/bin`) | yes | no |
| `xdg.enable` | yes | no |

Key finding: the mac `programs.zsh` is *vanilla* — vi-mode + starship + fzf +
direnv + zoxide (`cd=z`) + rex OSC133. It does **not** enable zsh
autosuggestions or syntax-highlighting. Every feature it uses also works in
bash, and the Linux `.bashrc` already has all of them **except zoxide is
installed but never initialized** (no `cd=z` on Linux).

## Tier 1 — close the real day-to-day gap (low risk, no shell switch)

Gets ~95% of the alignment without touching the shell choice.

1. In `misc/.bashrc`, initialize zoxide (it's already in `configs/bash.nix`
   packages) and alias `cd`:
   ```sh
   export _ZO_DOCTOR=0
   eval "$(zoxide init bash)"
   alias cd=z
   ```
2. Add `home.sessionPath = [ "$HOME/.local/bin" "$HOME/go/bin" ];` to
   `modules/home.nix` (mirrors `darwin/home.nix`).
3. Rebuild: `sudo nixos-rebuild --flake .#desktop switch --impure`.

## Tier 2 — true same-shell parity (optional upgrade)

Only worth doing if we want one `~/.zshrc` across both machines, and we make it
pay off by adding the features the mac config currently lacks.

1. Extract a shared home module `configs/home-common.nix` containing the
   cross-platform set:
   - `imports = [ starship git files tmux claude rex ]`
   - `programs.zsh` (moved verbatim from `darwin/home.nix`)
   - `home.sessionPath`, `xdg.enable`, `programs.home-manager.enable`,
     `home.stateVersion`
2. Slim both entrypoints to import it + keep only their real differences:
   - `darwin/home.nix` → `home-common` + `/Users/ezekiel` + `go-tools-install`
   - `modules/home.nix` → `home-common` + `/home/ezekiel`
3. Make zsh the Linux login shell: `users.users.ezekiel.shell = pkgs.zsh;` and
   `programs.zsh.enable = true;` at the system level (NixOS side).
4. Make the switch worthwhile — enable on BOTH via the shared module:
   ```nix
   programs.zsh.autosuggestion.enable = true;
   programs.zsh.syntaxHighlighting.enable = true;
   ```
5. **Verify before switching live:** `sudo nixos-rebuild --flake .#desktop build`
   (dry build, no `switch`) so a broken shell can never strand the session.
   Only `switch` once it builds clean.

## Notes / caveats

- `rex.nix` and `claude.nix` are config-only and portable — safe to import on
  Linux. (Rex itself: no Linux beta access yet, but the config is inert without
  the binary.)
- The mac leans on Homebrew for several tools (docker, go, zellij, direnv, GUI
  casks); the Linux side gets equivalents from nixpkgs. Parity is about the
  *shell/home experience*, not the package source.
- Recommendation: do **Tier 1** now (near-zero risk), treat **Tier 2** as a
  deliberate "level up the shell on both" project rather than a prerequisite for
  feeling aligned.
