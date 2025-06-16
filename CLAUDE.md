# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Nix flake configuration repository supporting both macOS (Darwin) and NixOS systems. The configuration uses Home Manager for user-level settings and follows a modular architecture.

## System Management Commands

**NixOS Systems:**
```bash
# Build and switch configurations
nixos-rebuild --flake .#bk switch --impure      # Desktop system
nixos-rebuild --flake .#laptop switch --impure  # Laptop system  
nixos-rebuild --flake .#desktop switch --impure # Desktop system
```

**macOS System:**
```bash
# Build and switch Darwin configuration
darwin-rebuild switch --flake .#macbook
```

**Flake Management:**
```bash
# Update flake inputs
nix flake update

# Show flake outputs
nix flake show
```

## Architecture

**Core Structure:**
- `flake.nix` - Main flake defining all system configurations
- `modules/` - Shared system-level modules (general.nix, packages.nix, etc.)
- `configs/` - Home Manager user configurations (apps like i3, tmux, git)
- `darwin/` - macOS-specific system and home configurations
- `nixos/` - NixOS system configurations and hardware definitions

**System Configurations:**
- **macBook** (aarch64-darwin): macOS system with user `ezekielenns`
- **bk, laptop, desktop** (x86_64-linux): NixOS systems with user `ezekiel`

**Package Management:**
- Stable packages from nixpkgs 25.05
- Unstable packages via `pkgs-unstable` overlay
- macOS supplements with Homebrew for unavailable packages

**Key Modules:**
- `modules/general.nix` - Base NixOS system configuration
- `configs/users.nix` - Home Manager user environment
- Machine-specific variations (i3status-rust.nix vs i3status-rust-dk.nix)
- Hardware-specific configs in `nixos/hardware/`

## Development Environment

**Editor:** Neovim configuration in `nvim/` directory with Lua-based setup
**Terminal:** Ghostty terminal across all platforms
**Shell:** Custom shell configurations with Starship prompt
**Window Manager:** i3 with comprehensive keybindings and workspace management