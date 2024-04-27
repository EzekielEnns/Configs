{config,pkgs,lib,...}:
let
myConfig = pkgs.vimUtils.buildVimPlugin {
  name = "my-config";
  src = ../nvim;
  recursive = true;
  # patchPhase = ''
  #   substituteInPlace lua/init.lua \
  #       --replace '@@omnisharp' '${pkgs.omnisharp-roslyn}' \
  #       --replace '@@dotnet' '${pkgs.dotnet-sdk_8}'
  # '';
};
myNeovim = pkgs.neovim.override {
  configure = {
    customRC = ''
      lua require("init")
    '';
    packages.myPlugins = with pkgs.vimPlugins; {
      start = [ 
        (pkgs.vimUtils.buildVimPlugin {
            name = "workspace-diagnostics.nvim";
            src = pkgs.fetchFromGitHub {
                repo = "workspace-diagnostics.nvim";
                owner = "artemave";
                rev = "main";
                sha256 = "sha256-3Rj4XCieQCcHxg+3/k0AfxtQZWeNm7aX23l3A+y5YUE=";
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
        nvim-treesitter
        vim-prettier
        nvim-treesitter.withAllGrammars
        nvim-treesitter-textobjects
        (nvim-treesitter.withPlugins (
           plugins: with plugins; [
            wgsl
            nix
            tsx
            toml
            python
            astro
            rust
            html
            typescript
            c
            go
            sql
            markdown
            xml
            kotlin
           ]
        ))
        nvim-lspconfig 
        trouble-nvim
        telescope-nvim
        nvim-cmp
        cmp-spell
        cmp-nvim-lsp
        cmp-buffer
        cmp-cmdline 
        cmp-path

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
        #python311
        #geckodriver

        #python311Packages.ruff-lsp
        #dotnet
        #omnisharp-roslyn
        #upkgs.csharp-ls

        #kotlin-language-server
        lemminx
        vscode-langservers-extracted
        quick-lint-js
        nil

        nodejs_latest
        nodePackages_latest.typescript-language-server
        nodePackages_latest.eslint
        nodePackages_latest.typescript-language-server

        #weird deps
        cargo
        rust-analyzer
        lua-language-server
        nodePackages_latest.pnpm


        # lang servers 
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
    ];
}
