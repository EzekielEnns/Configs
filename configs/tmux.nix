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
        # Let OSC sequences from a pane reach ghostty instead of being swallowed
        # by tmux, so Claude Code's desktop notifications actually surface.
        set -g allow-passthrough on

        set -g renumber-windows on

        # Default automatic-rename-format is #{pane_current_command}, and the
        # claude binary lives at ~/.local/share/claude/versions/<version>, so
        # every claude window was named "2.1.266". Name by directory instead.
        set -g automatic-rename-format '#{b:pane_current_path}'
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
        # Jump to the next window flagged with an alert. Claude Code rings the
        # bell when it finishes or wants input (preferredNotifChannel =
        # "terminal_bell"), which paints that window red in the status bar.
        bind -n M-a next-window -a

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
