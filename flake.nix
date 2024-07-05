{
#TODO add ytermusic to flake
#https://discourse.nixos.org/t/how-to-add-a-flake-package-to-system-configuration/14460/2
#https://nix-community.github.io/home-manager/index.xhtml#sec-flakes-nixos-module
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager= {
        url = "github:nix-community/home-manager/release-24.05";
        inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, home-manager,nixpkgs-unstable, ... }@inputs: 
    {
    nixosConfigurations = {
      bk = nixpkgs.lib.nixosSystem {
        specialArgs.inputs = inputs;
        system = "x86_64-linux";
        specialArgs.pkgs-unstable= import nixpkgs-unstable {
            system = "x86_64-linux";
            config.allowUnfree = true;
        };
        modules = 
          [ ./nixos/hardware/bk.nix ./nixos/bk.nix  ./modules/general.nix 
            home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.ezekiel = {
                    imports= [
                        ./configs/users.nix
                        ./configs/i3status-rust.nix
                    ];
                };
            }
          ];
      };
      laptop = nixpkgs.lib.nixosSystem {
        specialArgs.inputs = inputs;
        system = "x86_64-linux";
        specialArgs.pkgs-unstable= import nixpkgs-unstable {
            system = "x86_64-linux";
            config.allowUnfree = true;
        };
        modules =
          [ ./nixos/hardware/lp.nix ./nixos/lp.nix ./modules/general.nix 
            home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.ezekiel = {
                    imports= [
                        ./configs/users.nix
                        ./configs/i3status-rust.nix
                        ./configs/kitty-lp.nix
                    ];
                };
            }
          ];
      };
      desktop = nixpkgs.lib.nixosSystem {
        specialArgs.inputs = inputs;
        system = "x86_64-linux";
        specialArgs.pkgs-unstable= import nixpkgs-unstable {
            system = "x86_64-linux";
            config.allowUnfree = true;
        };
        modules = 
          [ ./nixos/hardware/dk.nix ./nixos/dk.nix  ./modules/general.nix 
            home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.ezekiel = {
                    imports= [
                        ./configs/users.nix
                        ./configs/i3status-rust-dk.nix
                    ];
                };
            }
        ];
      };
    };
  };
}
