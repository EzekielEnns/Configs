{config,pkgs,lib,...}:
let
myConfig = pkgs.vimUtils.buildVimPlugin {
  name = "my-config";
  src = ../nvim;
  recursive = true;
};
myNeovim = pkgs.neovim.override {
  configure = {
    customRC = ''
      lua require("init")
    '';
    packages.myPlugins = with pkgs.vimPlugins; {
      start = [ 
        (pkgs.vimUtils.buildVimPlugin {
            name = "Spelunker.vim";
            src = pkgs.fetchFromGitHub {
                repo = "spelunker.vim";
                owner = "kamykn";
                rev = "master";
                sha256 = "sha256-/1MN2KU5+rJhjt7FALvvwmTKRk3n29tU/XQdt1Q5OTE=";
            };
         })
        (pkgs.vimUtils.buildVimPlugin {
            name = "winresizer";
            src = pkgs.fetchFromGitHub {
                repo = "winresizer";
                owner = "simeji";
                rev = "master";
                sha256 = "sha256-5LR9A23BvpCBY9QVSF9PadRuDSBjv+knHSmdQn/3mH0=";
            };
         })
        rustaceanvim
        fidget-nvim
        vim-choosewin
        nvim-treesitter
        vim-prettier
        nvim-treesitter.withAllGrammars
        nvim-treesitter-textobjects
        nvim-lspconfig 
        trouble-nvim
        telescope-nvim
        nvim-cmp
        cmp-spell
        cmp-nvim-lsp
        cmp-buffer
        cmp-cmdline 
        cmp-path
        vim-tmux-navigator
        luasnip
        cmp_luasnip
        lsp_signature-nvim
        omnisharp-extended-lsp-nvim
        formatter-nvim 
        nvim-web-devicons 
        papercolor-theme
        vim-gitgutter
        which-key-nvim
        nvim-autopairs
        git-blame-nvim
        plenary-nvim
        typescript-tools-nvim

        comment-nvim
        myConfig 
      ];
      opt = [ ];
    };
  };
};
in {
    environment.systemPackages = with pkgs; [
        tree-sitter
        lemminx
        vscode-langservers-extracted
        quick-lint-js
        nil
        rustc
        nodejs_latest
        nodePackages_latest.typescript-language-server
        nodePackages_latest.eslint
        nodePackages_latest.typescript-language-server
        typescript

        cabal-install
        ghc
        haskell-language-server

        cargo
        rust-analyzer
        lua-language-server
        nodePackages_latest.pnpm
        nodePackages.svelte-language-server

        ltex-ls
        texlab
        marksman
        tailwindcss-language-server
        gopls
        terraform-ls
        libclang
        nodePackages.prettier
        vscode-langservers-extracted
        
        #need
        git
        myNeovim
        go
    ];
}
