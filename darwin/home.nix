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
        # re-bind fzf widgets after vi-mode reset (bindkey -v wipes them)
        if typeset -f fzf-history-widget >/dev/null; then
          bindkey '^R' fzf-history-widget
        fi
        if typeset -f fzf-file-widget >/dev/null; then
          bindkey '^T' fzf-file-widget
        fi
        if typeset -f fzf-cd-widget >/dev/null; then
          bindkey '\ec' fzf-cd-widget
        fi
        eval "$(starship init zsh)"
        eval "$(direnv hook zsh)"
        export _ZO_DOCTOR=0
        eval "$(zoxide init zsh)"
        alias cd=z
      '';
    };
    home.stateVersion = "23.11";
  };
}
