{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
  };
  outputs = { self, nixpkgs, flake-utils }:
        nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
                 /etc/nixos/hardware-configuration.nix
                ./laptop.nix
                ./general.nix
            ]
        };
        nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              /etc/nixos/hardware-configuration.nix
              ./desktop.nix
              ./general.nix
            ]
        };
}
