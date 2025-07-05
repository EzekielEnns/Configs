{config,pkgs,pkgs-unstable,lib,...}:
let
tsgo = pkgs.buildNpmPackage {
    pname = "tsgo";
#update version, 
#1. use the end stub in url and version
    version = "7.0.0-dev.20250705.1";
    src = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@typescript/native-preview/-/native-preview-7.0.0-dev.20250705.1.tgz";
#2. nix flake update + build switch 
        sha256 = "sha256-rr0HVxz5axXO3/3G1TH4XlRuT9XMckqD/x+mmOs1Em0=";
    };
#3. do a npm i for the package, updating the lock file or npm update
#4. use lib.fakeHash, do a build switch
#5. update hash
    npmDepsHash = "sha256-cl5TH47ha5EHPpf5K7pGfogBfARHn+q1uP7/u6uWNGU=";
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
in {
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
        
        # Custom packages
        tsgo
        myNeovim
        pkgs-unstable.claude-code
        pkgs-unstable.rustc
        pkgs-unstable.rust-analyzer
        pkgs-unstable.cargo

    ];
}
