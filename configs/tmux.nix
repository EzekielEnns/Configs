{ pkgs, ... }:
{
  config = {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "finder";
        runtimeInputs = [ pkgs.fzf ];
        text = ''
          wp=$(find ~/Documents/repos -mindepth 1 -maxdepth 1 -type d | while read -r d; do basename "$d"; done | fzf --prompt="Select a repo: ") || exit
          cd ~/Documents/repos/"$wp" || exit
          tmux new -As "$wp"
        '';
      })
    ];

    programs.tmux = {
      enable = true;
      keyMode = "vi";
      mouse = true;
      baseIndex = 1;
      escapeTime = 0;
      historyLimit = 50000;
      terminal = "tmux-256color";
      plugins = with pkgs.tmuxPlugins; [
        {
          plugin = gruvbox;
          extraConfig = "set -g @tmux-gruvbox 'dark'";
        }
        {
          plugin = resurrect;
          extraConfig = ''
            set -g @resurrect-capture-pane-contents 'on'
            # Relaunch claude sessions on restore; --continue picks up the most
            # recent conversation for the window's cwd.
            set -g @resurrect-processes '"~claude->claude --continue"'
          '';
        }
        {
          # continuum must stay last: it hooks status-right and autostarts saves
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '5'
          '';
        }
      ];
      extraConfig = ''
        set -g renumber-windows on
        set -g set-clipboard on
        set -g detach-on-destroy off

        # Alt bindings carried over from zellij (no prefix needed)
        bind -n M-n split-window -h -c "#{pane_current_path}"
        bind -n M-m split-window -v -c "#{pane_current_path}"
        bind -n M-x kill-pane
        bind -n M-. new-window -c "#{pane_current_path}"
        bind -n M-l next-window
        bind -n M-h previous-window
        bind -n M-\; select-pane -t :.+
        bind -n M-, select-pane -t :.-
        bind -n M-s choose-tree -Zs

        # "Floating pane": popup running a persistent scratch session.
        # Toggles closed if invoked from inside the popup.
        bind -n M-f if-shell -F '#{==:#{session_name},scratch}' 'detach-client' 'display-popup -E -w 80% -h 75% "tmux new-session -A -s scratch"'

        # Resize with Alt+arrows (zellij had a resize mode; this is direct)
        bind -n M-Left resize-pane -L 5
        bind -n M-Right resize-pane -R 5
        bind -n M-Down resize-pane -D 3
        bind -n M-Up resize-pane -U 3
      '';
    };
  };
}
