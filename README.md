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



- [ ] clean up editor flow
    - custom snippets
    x line ref copy pastier
    x git-branch/blame fix
    x try getting https://github.com/stephansama/nvim/blob/main/lsp/tsgo.lua tsgo working again
    x follow this https://madprofessorblog.org/articles/how-to-install-and-configure-typescript-go-as-an-lsp-in-neovim/
    - fix snippets
    - fix keybinds to make easier to deal with 
    - maybe add harpoon/multi file jumps??
    x undo tree
    x disable git branch on nerwrt
