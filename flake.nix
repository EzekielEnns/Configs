{
  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/release-23.05"; };

  };
  outputs = { self, nixpkgs, ... }: {

    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {

      system = "x86_64-linux";
      #system = "x86_64-linux";
      modules =
        [ ./nixos/laptop-hw.nix ./nixos/laptop.nix ./nixos/general.nix ];
    };
    #     nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
    #         #system = "x86_64-linux";
    #         modules = [
    #           ./nixos/desktop.nix
    #           ./nixos/general.nix
    #         ];
    #     };
  };
}
