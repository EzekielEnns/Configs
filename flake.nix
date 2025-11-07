{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty = {
      url = "github:ghostty-org/ghostty";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    zellij = {
      url = "github:a-kenji/zellij-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # NOTE: bring `ghostty` & `zellij` into scope by using `inputs.<name>` inside
  # or add them to this arg list (both work).
  outputs =
    { self
    , nixpkgs
    , nixpkgs-unstable
    , home-manager
    , nix-darwin
    , ...
    }@inputs:
    let
      # helpers
      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      mkUnstable =
        system:
        import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };

      latestPkgs = system: {
        ghostty = inputs.ghostty.packages.${system}.default;
        zellij = inputs.zellij.packages.${system}.default;
      };

      hmModule =
        { system
        , user
        , extraImports ? [ ]
        ,
        }:
        [
          home-manager.nixosModules.home-manager
          {
            _module.args = { }; # keep default
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${user} = {
              imports = extraImports;
            };
            # expose unstable pkgs to HM if you need them
            home-manager.extraSpecialArgs.pkgs-unstable = mkUnstable system;
          }
        ];

      baseSystemModule =
        system:
        { config, pkgs, ... }:
        let
          lp = latestPkgs system;
        in
        {
          environment.systemPackages = [
            lp.ghostty
            lp.zellij
          ];
        };
    in
    {
      ######################
      # macOS (Darwin host)
      ######################
      darwinConfigurations.macbook = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs.pkgs-unstable = mkUnstable "aarch64-darwin";
        modules = [
          ./darwin/config.nix
          (home-manager.darwinModules.home-manager)
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.ezekielenns = {
              imports = [ ./darwin/home.nix ];
            };
          }
        ];
      };

      ################
      # NixOS hosts
      ################
      nixosConfigurations =
        let
          mkHost =
            { name
            , system
            , hw
            , host
            , hmUser
            , hmImports ? [ ]
            ,
            }:
            nixpkgs.lib.nixosSystem {
              inherit system;
              specialArgs = {
                inherit inputs;
                pkgs-unstable = mkUnstable system;
              };
              modules = [
                (baseSystemModule system)
                hw
                host
                ./modules/general.nix
              ]
              ++ (hmModule {
                inherit system;
                user = hmUser;
                extraImports = hmImports;
              });
            };
        in
        {
          bk = mkHost {
            name = "bk";
            system = "x86_64-linux";
            hw = ./nixos/hardware/bk.nix;
            host = ./nixos/bk.nix;
            hmUser = "ezekiel";
            hmImports = [
              ./configs/users.nix
              ./configs/i3status-rust.nix
            ];
          };

          laptop = mkHost {
            name = "laptop";
            system = "x86_64-linux";
            hw = ./nixos/hardware/lp.nix;
            host = ./nixos/lp.nix;
            hmUser = "ezekiel";
            hmImports = [
              ./configs/users.nix
              ./configs/i3status-rust.nix
              ./configs/kitty-lp.nix
            ];
          };

          desktop = mkHost {
            name = "desktop";
            system = "x86_64-linux";
            hw = ./nixos/hardware/dk.nix;
            host = ./nixos/dk.nix;
            hmUser = "ezekiel";
            hmImports = [
              ./configs/users.nix
              ./configs/i3status-rust-dk.nix
            ];
          };
        };
    };
}
