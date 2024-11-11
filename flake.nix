{
#example setup https://github.com/dustinlyons/nixos-config?tab=readme-ov-file#nix-config-for-macos--nixos
#tutorial https://nixcademy.com/posts/nix-on-macos/
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager= {
        url = "github:nix-community/home-manager/release-24.05";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    # nix-darwin = {
    #   url = "github:lnl7/nix-darwin";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };
  outputs = { nixpkgs, home-manager,nixpkgs-unstable,nix-darwin, ... }@inputs: 
    {
#     darwinConfigurations = {
#       macbook = nix-darwin.lib.darwinSystem {
#         system = "x86_64-darwin";
#         modules = [
# #TODO          ./darwin/macbook.nix
#           ./modules/general.nix
#https://github.com/rounakdatta/dotfiles/blob/c9d6cb081daf5cc89ebea0c6f7817f21b061aff4/flake.nix#L66
#           home-manager.nixosModules.home-manager
#           {
#             home-manager.useGlobalPkgs = true;
#             home-manager.useUserPackages = true;
#             home-manager.users.ezekiel = {
#               imports = [
#                 ./configs/users.nix
# #TODO                ./configs/kitty-mac.nix
#               ];
#             };
#           }
#         ];
#         specialArgs = { inherit inputs; };
#       };
#     };
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
