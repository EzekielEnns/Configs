{ pkgs, ... }:
let
  # Shared by the setting and the status line so the denominator can't drift.
  autoCompactWindow = 400000;

  # Reads the session JSON on stdin. rate_limits only exists for Pro/Max
  # subscribers and only after the first API response, hence the `// empty`s.
  statusLine = pkgs.writeShellScript "claude-statusline" ''
    input=$(${pkgs.coreutils}/bin/cat)
    jq=${pkgs.jq}/bin/jq

    # Context in tokens against the auto-compact threshold (not the full window),
    # e.g. "130k/400k". Used tokens are derived from the window percentage.
    ctx=$(echo "$input" | $jq -r '
      (.context_window.used_percentage // empty) as $p
      | (.context_window.context_window_size // 0) as $win
      | ${toString autoCompactWindow} as $cap
      | def k: if . >= 1000000 then "\(. / 1000000 | floor)M" else "\(. / 1000 | floor)k" end;
        "\($win * $p / 100 | k)/\(([$win, $cap] | min) | k)"')
    week=$(echo "$input" | $jq -r '.rate_limits.seven_day.used_percentage // empty')

    out="ctx ''${ctx:-0}"
    [ -n "$week" ] && out="$out | 7d $(printf '%.0f' "$week")%"
    echo "$out"
  '';
in
{
  config = {
    # ~/.claude/settings.json becomes a read-only store symlink, so this file is
    # the only place it changes: `/config`, `/theme` and `/model`'s "save as
    # default" can no longer write it. Edit here and rebuild instead.
    #
    # Claude Code still writes plenty of *other* things under ~/.claude
    # (history, sessions, projects, paste-cache) — only settings.json is owned.
    programs.claude-code = {
      enable = true;
      # claude is installed by its own native installer into ~/.local/bin;
      # null keeps home-manager from putting a second copy on PATH.
      package = null;

      settings = {
        model = "opus[1m]";
        tui = "fullscreen";
        editorMode = "vim";
        permissions.defaultMode = "auto";

        # Compact at ~400K tokens instead of the ~967K default on a 1M window.
        # Plain integer; a per-model value saved by /autocompact would override it.
        inherit autoCompactWindow;

        statusLine = {
          type = "command";
          command = "${statusLine}";
        };

        # Compacts long conversations while idle, before the prompt cache expires.
        idleCompaction = true;

        env = {
          # Subagents without their own `model:` run on Sonnet instead of
          # inheriting Opus. Agent frontmatter still wins; built-in Explore/Plan
          # are unaffected (add CLAUDE_CODE_SUBAGENT_MODEL_FORCE = "1" to cover them).
          CLAUDE_CODE_SUBAGENT_MODEL = "sonnet";
        };

        # Emit an OSC 777 desktop notification, which ghostty turns into a real
        # macOS banner carrying Claude's message. Requires `allow-passthrough on`
        # in tmux (configs/tmux.nix) or tmux swallows the sequence.
        # The alternative, "terminal_bell", flags the tmux window red instead but
        # produces no banner: on macOS ghostty's `system` bell feature is only
        # the alert sound. Claude picks one channel, so it is one or the other.
        preferredNotifChannel = "ghostty";

        # What `rex skill setup` would add here if this file were writable:
        # tells each session it's running in Rex, and which session/terminal.
        hooks.SessionStart = [
          {
            hooks = [
              {
                type = "command";
                command = "/bin/sh -c 'rex __internal session-start --agent claude 2>/dev/null || true'";
                timeout = 5;
              }
            ];
          }
        ];

        voice = {
          enabled = false;
          mode = "tap";
        };
        voiceEnabled = false;
        agentPushNotifEnabled = true;

        # "I have seen this dialog" flags — pinned so they stay dismissed.
        skipAutoPermissionPrompt = true;
        skipWorkflowUsageWarning = true;
      };
    };

    # The module doesn't set force, and a real settings.json already exists on
    # this machine; without this, activation refuses to clobber it.
    home.file.".claude/settings.json".force = true;

    # Stub from `rex skill setup`; the real guide comes from the installed rex.
    home.file.".claude/skills/rex/SKILL.md".text = ''
      ---
      name: rex
      description: Use the rex CLI to manage Rex sessions, open tabs, arrange panes, run commands, inspect terminal output, and control connected Rex apps.
      metadata:
        rex-stub: "2"
      ---
      <!-- Installed by "rex skill setup". Remove it with "rex skill remove". -->

      Run `rex __internal skill` and follow the guide it prints. The guide comes from
      the installed Rex CLI, so it describes the commands available in that version.

      If the command fails, the installed Rex version predates the guide. Start with
      `rex whoami --json`, then use `rex --help` and `rex COMMAND --help`.
    '';
  };
}
