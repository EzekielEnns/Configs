{
#https://nix-community.github.io/home-manager/index.xhtml#sec-flakes-nixos-module
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, home-manager, ... }: {

    nixosConfigurations = {
      bk = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules =
          [ ./nixos/bk-hw.nix ./nixos/bk.nix  ./nixos/general.nix ];
      };
      laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules =
          [ ./nixos/laptop-hw.nix ./nixos/laptop.nix ./nixos/general.nix ];
      };
      desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./nixos/desktop-hw.nix ./nixos/desktop.nix ./nixos/general.nix ];
      };
    };
  };
}
