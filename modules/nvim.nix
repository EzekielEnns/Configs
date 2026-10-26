{ config
, pkgs
, pkgs-unstable
, lib
, ...
}:
let
  myConfig = pkgs.vimUtils.buildVimPlugin {
    name = "my-config";
    src = ../nvim;
    recursive = true;
    doCheck = false;
  };
  myNeovim = pkgs-unstable.neovim.override {
    configure = {
      customRC = ''
        lua require("init")
      '';
      packages.myPlugins = with pkgs.vimPlugins; {
        start = [
          # (pkgs.vimUtils.buildVimPlugin {
          #     name = "mdx.nvim";
          #     src = pkgs.fetchFromGitHub {
          #         repo = "mdx.nvim";
          #         owner = "davidmh";
          #         rev = "main";
          #         sha256 = "sha256-jpMcrWx/Rg9sMfkQFXnIM8VB5qRuSB/70wuSh6Y5uFk=";
          #     };
          #  })
          # (pkgs.vimUtils.buildVimPlugin {
          #     name = "winresizer";
          #     src = pkgs.fetchFromGitHub {
          #         repo = "winresizer";
          #         owner = "simeji";
          #         rev = "master";
          #         sha256 = "sha256-5LR9A23BvpCBY9QVSF9PadRuDSBjv+knHSmdQn/3mH0=";
          #     };
          #  })
          myConfig
        ];
        opt = [ ];
      };
    };
  };
in
{

  environment.variables = {
    OPENAI_API_BASE = "http://ai.lan:9292/v1";
    OPENAI_API_KEY = "nope";
    AIDER_MODEL = "openai/code";
  };
  environment.systemPackages = with pkgs; [
    # Language servers and tools
    pkgs-unstable.basedpyright
    pkgs-unstable.ruff
    # pyrepl.nvim shells out to `jupytext` to turn .ipynb into py:percent
    # scripts and back; the REPL packages themselves live in the project venv
    # (:PyreplInstall uv).
    python3Packages.jupytext
    efm-langserver
    nodejs_24
    eslint_d
    typescript-language-server
    typescript
    codespell
    lua-language-server
    vscode-langservers-extracted
    tailwindcss-language-server
    mdx-language-server
    pnpm
    terraform-ls
    nodePackages.prettier
    prettierd
    stylua
    # Required for lazy.nvim plugin management
    git
    curl
    # nvim-treesitter (main branch) shells out to `tree-sitter build`;
    # it requires CLI >= 0.26.1, which stable does not have yet.
    pkgs-unstable.tree-sitter

    pkgs-unstable.rustup
    #    pkgs-unstable.omnisharp-roslyn
    pkgs-unstable.bun
    myNeovim
    alejandra # very popular, opinionated
    nixfmt-rfc-style
    nixpkgs-fmt # nixpkgs style
    terraform
  ]
  # Go toolchain + editor helpers (see nvim/lua/plugins/go.lua), NixOS only.
  # golangci-lint refuses to run when a project's go.mod targets a Go newer
  # than the one it was built with, and nixpkgs lags Go releases, so on
  # macOS the whole Go stack lives outside Nix: `brew install go
  # golangci-lint` (darwin/config.nix) and `go-tools-install` for the rest
  # (darwin/home.nix).
  # A C compiler for tree-sitter parsers, Linux only: on macOS this gcc became `cc` and
  # can't link Rust (or other) programs against the macOS SDK (no libiconv), while Xcode's
  # clang at /usr/bin/cc does both.
  ++ lib.optionals pkgs.stdenv.isLinux [ gcc ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs-unstable.go
    pkgs-unstable.gopls
    pkgs-unstable.gotools # goimports, gorename, ...
    pkgs-unstable.golangci-lint
    pkgs-unstable.golangci-lint-langserver # golangci_lint_ls in lspconfig.lua
    pkgs-unstable.delve # :GoDebug
    pkgs-unstable.govulncheck # gopls run_govulncheck codelens
    gofumpt
    gomodifytags # :GoAddTag / :GoRmTag
    gotests # :GoAddTest / :GoAddAllTest generation
    impl # :GoImpl
    iferr # :GoIfErr
  ];
}
