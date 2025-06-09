{config,pkgs,pkgs-unstable,lib,...}:
let
myConfig = pkgs.vimUtils.buildVimPlugin {
  name = "my-config";
  src = ../nvim;
  recursive = true;
  dependencies = with pkgs.vimPlugins; [
        plenary-nvim
        typescript-tools-nvim
        fidget-nvim
        lspkind-nvim
#tree sitter
        nvim-treesitter
        nvim-treesitter.withAllGrammars
        nvim-treesitter-textobjects
        nvim-treesitter-textobjects
        nvim-treesitter-parsers.go
        nvim-treesitter-parsers.gomod
        nvim-treesitter-parsers.gosum
#lsp

        nvim-lspconfig 
        trouble-nvim
        nvim-lint
#completion
        nvim-cmp
        cmp-spell
        cmp-nvim-lsp
        cmp-buffer
        cmp-cmdline 
        cmp-path
        cmp_luasnip
        cmp-nvim-lsp
        telescope-nvim
        vim-tmux-navigator
        go-nvim
luasnip
        lsp_signature-nvim
        neoformat
        nvim-autopairs
        nvim-web-devicons 
        gruvbox
        vim-gitgutter
        which-key-nvim
        git-blame-nvim
        comment-nvim
  ];
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
in {
    environment.systemPackages = with pkgs; [
        efm-langserver
        tree-sitter
        #lemminx
        #vscode-langservers-extracted
        # quick-lint-js
        # nil
        nodejs_24
        eslint_d
        typescript-language-server
        typescript
        codespell
        # cargo
        # rust-analyzer
        # rustc
        # libclang
        lua-language-server
        pnpm
        terraform-ls
        prettierd
        stylua
        #nixpkgs-fmt
        git
        gofumpt
        gopls
        go
        myNeovim
    ];
}
