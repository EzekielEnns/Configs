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
      promptInit = ''
        bindkey -v
        eval "$(starship init zsh)"
        eval "$(direnv hook zsh)"
        eval "$(zoxide init zsh)"
      '';
    };
  };
}
