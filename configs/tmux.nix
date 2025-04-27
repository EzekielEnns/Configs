{pkgs,  ...}: 
#https://github.com/tmux-plugins/tmux-resurrect
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

         # set -ag terminal-overrides ",xterm-256color:RGB"
         # set  -g default-terminal "tmux-256color"
 programs.tmux = {
     enable = true;
     plugins = with pkgs.tmuxPlugins; [
         vim-tmux-navigator
         sensible
     ];
     extraConfig =  ''
         bind f display-popup -E "tmux list-windows -a -F '#{session_name}:#{window_index} - #{window_name}' \
                          | grep -v \"^$(tmux display-message -p '#S')\$\" \
                          | fzf --reverse \
                          | sed -E 's/\s-.*$//' \
                          | xargs -r tmux switch-client -t"
         #bind s display-popup -E finder
         #bind g display-popup
         bind-key r command-prompt -I "#W" "rename-window '%%'"
         #set -g mouse on
         set-option -g status-style bg=default
#TODO try  and fix this
         #set-option -g default-shell /bin/zsh
          #set-option -g default-command "reattach-to-user-namespace -l zsh"
         set-option -g default-command zsh
         # unbind s 
         # bind e choose-session
         # unbind l 
         bind-key h select-pane -L
         bind-key j select-pane -D
         bind-key k select-pane -U
         bind-key \; select-pane -R


         setw -g mode-keys vi
         bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'xclip -in -selection clipboard'
         set -g @plugin 'christoomey/vim-tmux-navigator'
         bind C-l send-keys 'C-l'
         run '~/.tmux/plugins/tpm/tpm'

         is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
         | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
         bind-key '"' if-shell "$is_vim" "split-window -h -p 20" "split-window -h"
         bind-key % if-shell "$is_vim" "split-window -v -p 10" "split-window -v"
         '';
 };
}
