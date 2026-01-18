{ pkgs, ... }:
{
  options = { };
  config = {
    environment.systemPackages = with pkgs; [
      fzf
      fastfetch
      ripgrep
      fzf-git-sh
      bat
      bashInteractive
      lsd
      zoxide
      tokei
      dust
      termdown
      git
      wget
      fastfetch
      unzip
      p7zip
      unrar
      tldr
    ];
    environment.variables = {
      EDITOR = "nvim";
      FZF_COMPLETION_OPTS = "--border --info=inline";
      VISUAL = "nvim";
      NIXPKGS_ALLOW_UNFREE = "1";
      FZF_CTRL_T_OPTS = "--walker-skip .git,node_modules,target --preview 'bat -n --color=always {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'";
    };
    environment.shellAliases = {
      ls = "lsd";
      cat = "bat";
      cd = "z";
    };
  };
}
