{ config, pkgs, ... }:

{
  imports = [
    ../modules/nvim.nix
    ./zsh.nix
    ./scripts.nix
  ];

  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;
  nix.settings.experimental-features = "nix-command flakes";
  system.defaults.dock.autohide-delay = 0.0;
  users.users.ezekielenns = {
        name = "ezekielenns";
        home = "/Users/ezekielenns";
    };
}
