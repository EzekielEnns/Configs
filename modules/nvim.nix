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
  myNeovim = pkgs.neovim.override {
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
  mcp-hub = pkgs.writeShellApplication {
    name = "mcp-hub";
    runtimeInputs = [ pkgs.nodejs_20 ]; # brings node + npm/npx
    text = ''exec npx --yes mcp-hub@latest "$@"'';
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
    efm-langserver
    tree-sitter
    nodejs_24
    eslint_d
    typescript-language-server
    typescript
    codespell
    lua-language-server
    vscode-langservers-extracted
    tailwindcss-language-server
    pnpm
    terraform-ls
    nodePackages.prettier
    prettierd
    stylua
    gofumpt
    gopls
    go
    # Required for lazy.nvim plugin management
    git
    curl
    gcc

    pkgs-unstable.rustup
    #    pkgs-unstable.omnisharp-roslyn
    pkgs-unstable.bun
    myNeovim
    # ai
    pkgs-unstable.claude-code
    pkgs-unstable.aider-chat
    alejandra # very popular, opinionated
    nixfmt-rfc-style
    nixpkgs-fmt # nixpkgs style
    mcp-hub
  ];
}
