# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal Nix flake managing both **nix-darwin** (macOS) and **NixOS** hosts from a single `flake.nix`, with `home-manager` integrated into each host. Also contains a Neovim config (`nvim/`), notes, and cheatsheets.

## Rebuild commands

- macOS (nix-darwin): `darwin-rebuild switch --flake .#macbook`
- NixOS desktop: `sudo nixos-rebuild --flake .#desktop switch --impure`

The README mentions a `<laptop|desktop>` placeholder, but `flake.nix` currently only defines the `desktop` NixOS host and the `macbook` Darwin host. Other host files exist under `nixos/` (`bk.nix`, `lp.nix`, `mini-thin.nix`) but are not wired into `flake.nix` outputs — they are stale or used out-of-band.

## Flake structure

`flake.nix` defines:
- `mkPkgs` / `mkUnstable` helpers and `pkgs-unstable` is passed via `specialArgs` to every host (so modules can use `pkgs-unstable.<thing>` for unstable packages while staying on the stable channel).
- `latestPkgs` pulls bleeding-edge `ghostty` / `zellij` / `zen` from their own flake inputs and exposes them via `baseSystemModule` (NixOS hosts only).
- `hmModule` wires `home-manager` into NixOS hosts; the Darwin host wires home-manager inline inside `darwinConfigurations.macbook`.
- `mkHost` factory builds NixOS hosts from `{ name, system, hw, host, hmUser, hmImports }`.

## Module layout (the big picture)

- `darwin/` — entry point for macOS. `config.nix` is the nix-darwin module; it imports `modules/nvim.nix` and `darwin/zsh.nix`. `darwin/home.nix` is the home-manager module for the macOS user.
- `nixos/` — per-host NixOS modules. `hardware/` holds hardware-configuration imports.
- `modules/` — shared modules consumed by NixOS hosts via `modules/general.nix`, which is the umbrella import (`packages`, `windowManager`, `virtualization`, `networking`, `nvim`, `shell`, plus `configs/bash.nix`). **Darwin does not import `general.nix`** — it cherry-picks `modules/nvim.nix` directly. When adding a shared module, decide whether it belongs in `general.nix` (Linux only) or needs to be imported by both `general.nix` and `darwin/config.nix`.
- `configs/` — cross-platform user/program config (`git.nix`, `starship.nix`, `bash.nix`, `users.nix`, `files.nix`). These are imported by either `darwin/home.nix` or `modules/general.nix` depending on scope.

## Conventions worth knowing

- Use `pkgs-unstable.<pkg>` (passed via `specialArgs`) for packages that need to track unstable; keep everything else on stable. See `modules/nvim.nix` for examples.
- For PATH additions on the user's shell, prefer `home.sessionPath` in `darwin/home.nix` (or the equivalent NixOS home-manager file) over hand-written `export PATH=...` in `environment.extraInit`. The latter exists in `darwin/config.nix` only for cases where home-manager can't handle it (Docker.app discovery).
- Neovim is built as a custom package (`myNeovim`) and added alongside `pkgs-unstable.aider-chat` etc. in `modules/nvim.nix`.
