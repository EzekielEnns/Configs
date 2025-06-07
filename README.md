# my personal config
this config is transtioning from using standard nix to using flakes
so far the install steps are as follows:
`nixos-rebuild --flake .#<laptop|desktop> switch --impure`
`sh scripts/update_config.sh`

## VS Code
The `.vscode` folder contains keybindings and settings mirroring my Neovim setup for TypeScript development.
Recommended extensions:

- `vscodevim.vim` for Vim keybindings
- `VSpaceCode.whichkey` to show key hints similar to Neovim's WhichKey
- `rlivings39.fzf-quick-open` for fuzzy file and text search (Telescope like)
