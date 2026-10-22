{ config, lib, pkgs, ... }:
let
  # The rex CLI ships inside the app bundle. Rex adds this dir to PATH itself,
  # but nix-darwin's /etc/zshenv resets PATH and drops it.
  rexBin = "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS";

  # Exact bytes Rex wrote after "Migrate theme from Ghostty config" (Gruvbox
  # Dark). The id must match the theme IDs below.
  themes = ./rex-themes.json;
  gruvboxId = "custom-339FE27E-DA72-4178-AD24-933E145C97E0";
in
{
  config = {
    home.sessionPath = [ rexBin ];

    # Appearance lives in the app's plist, not init.lua, so pin it here. Rebuilds
    # overwrite whatever was changed for these keys in Rex's Settings.
    targets.darwin.defaults."com.superlogical.rex" = {
      # Same theme for both so macOS light mode doesn't swap to merino-light
      "Workspace.darkThemeID" = gruvboxId;
      "Workspace.lightThemeID" = gruvboxId;
      "Workspace.terminalFontName" = "Monofur Nerd Font Mono";
      "Workspace.terminalFontPointSize" = 15.0;
      "Workspace.interfaceStyle" = "useTheme";
      # Extra line height in percent; Monofur sits tight at 100%
      "Workspace.terminalCellHeightPercent" = 10.0;
      # Insert Path suggests recently used folders too
      "Workspace.insertPathShowsRecentPaths" = true;

      # Chrome
      "Workspace.tabStyle" = "horizontal";
      "Workspace.tabsFillAvailableSpace" = true;
      "Workspace.tabIconCount" = 1;
      "Workspace.tabIconTintMode" = "off";
      "Workspace.sidebarPosition" = "left";
      "Workspace.paneDensity" = "compact";
      "Workspace.inactivePaneFadeMode" = "text";
      "Workspace.focusFollowsMouse" = true;
      "Workspace.notificationPosition" = "top-right";
      "Workspace.showsIdleProgramsInActivity" = true;
      "Workspace.appIcon" = "dark";
      "Workspace.appIconVisibility" = "dockAndMenuBar";
      "Workspace.showsPaneHeaders" = false;
      "Workspace.usesPaneGlass" = false;
      "Workspace.showsKeySequenceHints" = false;
      # Edges take the program's background (nvim) instead of the theme's
      "Workspace.terminalPaddingColor" = "extend";
      "Workspace.tintsPanesWithProgramBackground" = true;
      "Workspace.balancesSplitsOnCreation" = true;
      "Workspace.prefersGeneratedTitles" = true;
      # Other options: commandPalette, activity / splitRight, splitDown, zoom, close
      "Workspace.hiddenChromeButtons" = [ "newTab" ];
      "Workspace.hiddenPaneButtons" = [ "splitRight" "splitDown" "zoom" "close" ];

      # Terminal, matching the old ghostty config
      "Workspace.terminalCopyOnSelect" = true;
      "Workspace.terminalCopyAnimation" = false;
      "Workspace.terminalCursorStyle" = "block";
      "Workspace.terminalCursorStyleForced" = true;
      # 0 = no blink, like cursor-style-blink = false in ghostty
      "Workspace.terminalCursorBlinkIntervalMilliseconds" = 0;
      "Workspace.darkUsesExtendedThemePalette" = true;
      # Off to compare typing feel against ghostty
      "Workspace.terminalAllowsLigatures" = false;
      "Workspace.terminalImproveTextContrast" = false;

      # Agent status comes from Rex itself. Claude's own OSC 777 banners
      # (configs/claude.nix) are dropped: they piled up in Notification Center.
      "Workspace.showsProgramStatusInTabs" = true;
      "Workspace.showsProgramActivityNotifications" = true;
      "Workspace.playsProgramActivitySounds" = true;
      "Workspace.showsProgramActivityDockBadge" = true;
      "Workspace.allowsTerminalNotifications" = false;

      # Overlay scroll bars that show only while scrolling, for Rex alone.
      # macOS otherwise keeps them on screen whenever a mouse is plugged in.
      AppleShowScrollBars = "WhenScrolling";

      # Lets the rex CLI drive the app, e.g. `finder` switching sessions
      "rex.client.remoteControl" = true;
    };

    # Rex stores custom themes as a data blob, which targets.darwin.defaults
    # can't express.
    home.activation.rexThemes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run /usr/bin/defaults write com.superlogical.rex Workspace.customThemes \
        -data "$(${pkgs.unixtools.xxd}/bin/xxd -p ${themes} | tr -d '\n')"
    '';

    # Installs the xterm-rex terminfo entry in ~/.terminfo plus Rex's ssh guard
    # (an Include in ~/.ssh/config), so panes get TERM=xterm-rex, Rex's copy of
    # ghostty's entry, instead of plain xterm-256color. Repeating it is harmless.
    home.activation.rexTerminfo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run "${rexBin}/rex" terminfo setup --autostart=false >/dev/null || true
    '';

    # Only keys, actions, modes and hosts live here. Theme, font, cursor and
    # chrome settings are still in the app's plist (com.superlogical.rex).
    xdg.configFile."rex/init.lua" = {
      force = true;
      text = ''
        -- Alt bindings carried over from tmux (configs/tmux.nix), no prefix
        rex.bind("alt+n", "pane.split", { direction = "right" })
        rex.bind("alt+m", "pane.split", { direction = "down" })
        rex.bind("alt+x", "pane.close")
        rex.bind("alt+.", "client.tab.new")
        rex.bind("alt+l", "client.tab.next")
        rex.bind("alt+h", "client.tab.previous")
        rex.bind("alt+;", "pane.focus_next")
        rex.bind("alt+,", "pane.focus_previous")
        rex.bind("alt+s", "session.switch")
        -- Sessions on j/k, next to tabs on h/l
        rex.bind("alt+j", "session.next")
        rex.bind("alt+k", "session.previous")

        rex.bind("alt+left", "pane.resize", { direction = "left" })
        rex.bind("alt+right", "pane.resize", { direction = "right" })
        rex.bind("alt+down", "pane.resize", { direction = "down" })
        rex.bind("alt+up", "pane.resize", { direction = "up" })

        -- Resize mode from the old zellij config: ctrl+s, then hjkl or arrows
        -- (shift for bigger steps), = to balance, esc/enter/ctrl+s to leave.
        -- Exclusive so stray keys don't type into the terminal.
        rex.mode("resize", { exclusive = true })
        rex.bind("ctrl+s", "client.mode.enter", { name = "resize" })
        for _, d in ipairs({
          { "h", "left" }, { "j", "down" }, { "k", "up" }, { "l", "right" },
          { "left", "left" }, { "down", "down" }, { "up", "up" }, { "right", "right" },
        }) do
          rex.bind("resize/" .. d[1], "pane.resize", { direction = d[2] })
          rex.bind("resize/shift+" .. d[1], "pane.resize", { direction = d[2], amount = 15 })
        end
        rex.bind("resize/=", "pane.balance")
        rex.bind("resize/enter", "client.mode.exit")
        rex.bind("resize/ctrl+s", "client.mode.exit")

        -- Scroll mode, stand-in for tmux copy mode: alt+u or ctrl+a [, then k/j or
        -- up/down. Shells jump between prompts (Rex has no line/page scroll
        -- action yet); Claude Code, nvim and other full-screen programs get
        -- Page Up / Page Down (rex-scroll.lua).
        dofile(os.getenv("HOME") .. "/.config/rex/scroll.lua")
        rex.mode("scroll", { exclusive = true })
        rex.bind("ctrl+a>[", "client.mode.enter", { name = "scroll" })
        rex.bind("alt+u", "client.mode.enter", { name = "scroll" })
        for _, k in ipairs({ "k", "up" }) do
          rex.bind("scroll/" .. k, "scroll_step", { direction = "up" })
        end
        for _, k in ipairs({ "j", "down" }) do
          rex.bind("scroll/" .. k, "scroll_step", { direction = "down" })
        end
        rex.bind("scroll/q", "client.mode.exit")
        rex.bind("scroll/enter", "client.mode.exit")

        -- Cmd+K is the session switcher by default; make it the palette
        rex.bind("cmd+k", "client.palette.toggle")
        rex.bind("cmd+s", "session.switch")

        -- ctrl+a prefix carried over from ghostty (configs/files.nix)
        rex.bind("ctrl+a>n", "client.window.new")
        rex.bind("ctrl+a>h", "client.sidebar.toggle")
        -- ctrl+a now starts a sequence; press it twice for beginning-of-line
        rex.bind("ctrl+a>ctrl+a", "pane.send_key", { key = "ctrl+a" })

        -- Flip Layout: turn every split in the tab, for moving between the
        -- portrait monitor and the laptop screen. ctrl+a space, like tmux's
        -- next-layout.
        dofile(os.getenv("HOME") .. "/.config/rex/layout.lua")
        rex.bind("ctrl+a>space", "flip_layout")
      '';
    };

    # Rex doesn't watch init.lua. Skip quietly when the server isn't running.
    home.activation.rexConfigReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ -S "$HOME/Library/Application Support/rex/server.sock" ]; then
        run "${rexBin}/rex" config reload || true
      fi
    '';

    # Session save/restore, standing in for tmux-resurrect + continuum. The
    # daemon restores whatever a server restart lost, then saves on every
    # change to ~/.local/state/rex-resurrect/snapshot.json.
    xdg.configFile."rex/resurrect.lua".source = ./rex-resurrect.lua;
    xdg.configFile."rex/layout.lua".source = ./rex-layout.lua;
    xdg.configFile."rex/scroll.lua".source = ./rex-scroll.lua;

    # Exits when the server goes away; launchd brings it back, and on a fresh
    # server it restores. --autostart=false leaves starting the server to Rex.app.
    launchd.agents.rex-resurrect = {
      enable = true;
      config = {
        ProgramArguments = [
          "${rexBin}/rex" "do" "--all" "--autostart=false"
          "${config.xdg.configHome}/rex/resurrect.lua" "mode=daemon"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 30;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/rex-resurrect.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/rex-resurrect.log";
      };
    };

    home.packages = [
      (pkgs.writeShellScriptBin "rex-restore" ''
        exec "${rexBin}/rex" do "${config.xdg.configHome}/rex/resurrect.lua" mode=restore
      '')
      # tmux-to-rex [SESSION [LABEL]]: snapshot the running tmux with
      # tmux-resurrect, then rebuild it (or just SESSION) in Rex. Existing Rex
      # labels are skipped, so pass LABEL to bring a second copy over.
      (pkgs.writeShellScriptBin "tmux-to-rex" ''
        set -eu
        save=$(tmux show -gv @resurrect-save-script-path)
        "$save" quiet
        args=(mode=tmux)
        [ -n "''${1:-}" ] && args+=("session=$1")
        [ -n "''${2:-}" ] && args+=("as=$2")
        exec "${rexBin}/rex" do "${config.xdg.configHome}/rex/resurrect.lua" "''${args[@]}"
      '')
    ];
  };
}
