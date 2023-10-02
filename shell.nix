{ pkgs ? import <nixpkgs> { } }:
let
  myConfig = pkgs.vimUtils.buildVimPlugin {
    name = "my-config";
    src = ./myNeovim;
    recursive = true;
  };

  unstableTarball = fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  # The neovim package with your configuration
  unstable = import unstableTarball { };
  myNeovim = pkgs.neovim.override {
    configure = {
      customRC = ''
        lua require("init")
      '';
      packages.myPlugins = {
        start = [
          myConfig # my own configuration
        ];
        opt = [ ];
      };
    };
  };
in with pkgs;
pkgs.mkShell {
  nativeBuildInputs = [
    # term-tools
    inotify-tools
    mdcat
    kitty
    zellij
    lazygit
    lf
    # lsps/lang tools
    vimPlugins.nvim-treesitter-parsers.astro
    statix
    marksman
    terraform-ls
    nodePackages_latest.sql-formatter
    nodePackages_latest.typescript-language-server
    rust-analyzer
    gopls
    nodePackages_latest.vscode-langservers-extracted
    lua-language-server
    # formatters 
    nixfmt
    yamlfmt
    yamllint
    luaformatter
    nodePackages.prettier
    #shell
    nushell
    carapace
    # bash
    bash-completion
    git
    # plugins 
    myNeovim
  ];
}
