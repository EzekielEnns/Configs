{ pkgs, ... }:
{
  options = { };
  config = {
    environment.systemPackages = with pkgs; [
      fzf
      neofetch
      ripgrep
      fzf-git-sh
      bat
      bashInteractive
      lsd
    ];
    environment.variables = {
      EDITOR = "nvim";
      FZF_COMPLETION_OPTS = "--border --info=inline";
      VISUAL = "nvim";
      NIXPKGS_ALLOW_UNFREE = "1";
      FZF_CTRL_T_OPTS = "--walker-skip .git,node_modules,target --preview 'bat -n --color=always {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'";
    };
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      promptInit = ''
        bindkey -v
        eval "$(starship init zsh)"
        eval "$(direnv hook zsh)"
        eval "$(zoxide init zsh)"
      '';
    };
  };
}
