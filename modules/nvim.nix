{config,pkgs,pkgs-unstable,lib,...}:
let
tsgo = pkgs.buildNpmPackage {
    pname = "tsgo";
#update version, 
#1. use the end stub in url and version
    version = "7.0.0-dev.20250616.1";
    src = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@typescript/native-preview/-/native-preview-7.0.0-dev.20250616.1.tgz";
#2. nix flake update + build switch 
        sha256 = "sha256-F2B1k+LadJlALStJ2O+JG+KD5OwyBveo6T1vvhFhAb4=";
    };
#3. do a npm i for the package, updating the lock file
#4. use lib.fakeHash, do a build switch
#5. update hash
    npmDepsHash = "sha256-d+Su0g8GziIufu02R40You1pNRY8odQH/6GAMPhEvcE=";
    dontNpmBuild = true;
    postPatch = ''
      ls -l
      cp ${../package-lock.json} ./package-lock.json
      ls -l
    '';
};
myConfig = pkgs.vimUtils.buildVimPlugin {
  name = "my-config";
  src = ../nvim;
  recursive = true;
  dependencies = with pkgs.vimPlugins; [
        tsgo
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
        #ai
        avante-nvim
        nui-nvim
        #other
        nvim-notify
        noice-nvim
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
        tsgo
        myNeovim
        pkgs-unstable.claude-code
    ];
}
