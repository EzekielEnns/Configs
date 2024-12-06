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

         # set -ag terminal-overrides ",xterm-256color:RGB"
         # set  -g default-terminal "tmux-256color"
 programs.tmux = {
     enable = true;
     plugins = with pkgs.tmuxPlugins; [
         vim-tmux-navigator
         sensible
     ];
     extraConfig =  ''
         #set -g prefix C-s
         #set -g mouse on
         set-option -g status-style bg=default
         set-option -g default-shell /bin/zsh
         set-option -g default-command /bin/zsh
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
         #just for mac
         # set-option -g default-command "reattach-to-user-namespace -l zsh"
         '';
 };
}
