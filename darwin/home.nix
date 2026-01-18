{ ... }:
{
  imports = [
    ../configs/starship.nix
    ../configs/git.nix
    ../configs/files.nix
  ];
  options = { };
  config = {
    home.username = "ezekiel";
    home.homeDirectory = "/Users/ezekiel";
    xdg.enable = true;
    programs.home-manager.enable = true;
    home.stateVersion = "23.11";
  };
}
