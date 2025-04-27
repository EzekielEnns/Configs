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
        plenary-nvim
        (pkgs.vimUtils.buildVimPlugin {
            name = "typescript-tools.nvim";
            src = pkgs.fetchFromGitHub {
                repo = "typescript-tools.nvim";
                owner = "pmizio";
                rev = "master";
                sha256 = "sha256-JP86GWCaPl/Gl6FDa4Pnd0blq0S8JD1EraJLwxL37vg=";
            };
         })
        (pkgs.vimUtils.buildVimPlugin {
            name = "mdx.nvim";
            src = pkgs.fetchFromGitHub {
                repo = "mdx.nvim";
                owner = "davidmh";
                rev = "main";
                sha256 = "sha256-jpMcrWx/Rg9sMfkQFXnIM8VB5qRuSB/70wuSh6Y5uFk=";
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
        fidget-nvim
        vim-choosewin
        tailwind-tools-nvim
        lspkind-nvim
# for documenting and such
        copilot-vim
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
        nodejs_latest
        nodePackages_latest.eslint
        nodePackages_latest.typescript-language-server
        typescript
        tailwindcss-language-server
        cargo
        rust-analyzer
        rustc
        lua-language-server
        pnpm
        nodePackages.svelte-language-server

        gopls
        terraform-ls
        libclang
        nodePackages.prettier
        stylua
        nixpkgs-fmt
        
        #need
        git
        myNeovim
        go
    ];
}
