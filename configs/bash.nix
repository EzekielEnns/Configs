{ config, pkgs, ... }:
{
  options = { };
  config = {
    environment.etc.bashrc.text = builtins.readFile (../misc/.bashrc);
    environment.etc.inputrc.text = builtins.readFile (../misc/.inputrc);
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
