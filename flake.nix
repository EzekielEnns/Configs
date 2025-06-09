{
#example setup https://github.com/dustinlyons/nixos-config?tab=readme-ov-file#nix-config-for-macos--nixos
#tutorial https://nixcademy.com/posts/nix-on-macos/
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager= {
        url = "github:nix-community/home-manager/release-25.05";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };
  outputs = { nixpkgs, home-manager,nixpkgs-unstable,nix-darwin,    ... }@inputs: 
    {
    darwinConfigurations = {
      macbook = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs.pkgs-unstable= import nixpkgs-unstable {
            system = "aarch64-darwin";
            config.allowUnfree = true;
        };
        modules = [
        ./darwin/config.nix 
            home-manager.darwinModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.ezekielenns = {
                    imports= [ ./darwin/home.nix ];
                };
            }
          ];
      };
    };
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
                home-manager.extraSpecialArgs.pkgs-unstable = import nixpkgs-unstable {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
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
                home-manager.extraSpecialArgs.pkgs-unstable= import nixpkgs-unstable {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
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
                home-manager.extraSpecialArgs.pkgs-unstable= import nixpkgs-unstable {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
                };
            }
        ];
      };
    };
  };
}
