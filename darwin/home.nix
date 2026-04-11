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
    home.sessionPath = [ "$HOME/.local/bin" ];
    xdg.enable = true;
    programs.home-manager.enable = true;
    programs.zsh = {
      enable = true;
      initContent = ''
        bindkey -v
        eval "$(starship init zsh)"
        eval "$(direnv hook zsh)"
        eval "$(zoxide init zsh)"
        alias cd=z
      '';
    };
    home.stateVersion = "23.11";
  };
}
