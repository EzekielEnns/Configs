{pkgs,  ...}: 
let
  test = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-which-key";
    version = "main";
    src = pkgs.fetchFromGitHub {
      owner = "alexwforsythe";
      repo = "tmux-which-key";
      rev = "b4cd9d28da4d0a418d2af5f426a0d4b4e544ae10";
      sha256 = "sha256-ADUgh0sSs1N2AsLC7+LzZ8UPGnmMqvythy97lK4fYgw=";
    };
  };
in
{
 programs.tmux = {
     enable = true;
     plugins = [test];
     # extraConfig =  ''
     #     set -g mouse on
     #     set -ag terminal-overrides ",xterm-256color:RGB"
     #     set  -g default-terminal "tmux-256color"
     #     set-option -g status-style bg=default
     #
     #     set-option -g detach-on-destroy off
     #
     #     #Vim "beliver"
     #     unbind % # Split vertically
     #     unbind '"' # Split horizontally
     #     unbind s 
     #     bind e choose-session
     #     unbind l 
     #     bind 6 last-window
     #     bind v split-window -h -c "#{pane_current_path}"
     #     bind s split-window -v -c "#{pane_current_path}"
     #     bind h select-pane -L
     #     bind j select-pane -D
     #     bind k select-pane -U
     #     bind l select-pane -R
     #
     #
     #     set-window-option -g mode-keys vi
     #     bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'xclip -in -selection clipboard'
     #     '';
 };
}
