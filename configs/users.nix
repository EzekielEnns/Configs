#actually what is used
{ ... }:
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
  };
}
