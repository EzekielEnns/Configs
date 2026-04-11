{ ... }:
{
  imports = [
    ../modules/shell.nix
  ];
  options = { };
  config = {
    programs.zsh = {
      enable = true;
      enableFzfCompletion = true;
      enableFzfHistory = true;
      enableFzfGit = true;
    };
  };
}
