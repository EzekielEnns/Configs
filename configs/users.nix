#actually what is used
{ pkgs, ... }:
{
  imports = [
    ./starship.nix
    ./git.nix
    ./files.nix
  ];
  options = { };
  config = {
    home.username = "ezekiel";
    home.homeDirectory = "/home/ezekiel";
    programs.home-manager.enable = true;
    home.stateVersion = "23.11";

    # Launch Steam (and every game it spawns) on the NVIDIA dGPU via PRIME offload.
    # The `nvidia-offload` wrapper is defined in nixos/hardware/dk.nix.
    xdg.desktopEntries.steam = {
      name = "Steam";
      genericName = "Application for managing and playing games on Steam";
      exec = "nvidia-offload steam %U";
      icon = "steam";
      terminal = false;
      mimeType = [ "x-scheme-handler/steam" "x-scheme-handler/steamlink" ];
      categories = [ "Network" "FileTransfer" "Game" ];
      actions = {
        "Store" = { name = "Store"; exec = "nvidia-offload steam steam://store"; };
        "Library" = { name = "Library"; exec = "nvidia-offload steam steam://open/games"; };
        "Friends" = { name = "Friends"; exec = "nvidia-offload steam steam://open/friends"; };
        "Settings" = { name = "Settings"; exec = "nvidia-offload steam steam://open/settings"; };
        "BigPicture" = { name = "Big Picture"; exec = "nvidia-offload steam steam://open/bigpicture"; };
      };
    };
  };
}
