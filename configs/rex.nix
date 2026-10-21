{ lib, pkgs, ... }:
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

      # Lets the rex CLI drive the app, e.g. `finder` switching sessions
      "rex.client.remoteControl" = true;
    };

    # Rex stores custom themes as a data blob, which targets.darwin.defaults
    # can't express.
    home.activation.rexThemes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run /usr/bin/defaults write com.superlogical.rex Workspace.customThemes \
        -data "$(${pkgs.unixtools.xxd}/bin/xxd -p ${themes} | tr -d '\n')"
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

        rex.bind("alt+left", "pane.resize", { direction = "left" })
        rex.bind("alt+right", "pane.resize", { direction = "right" })
        rex.bind("alt+down", "pane.resize", { direction = "down" })
        rex.bind("alt+up", "pane.resize", { direction = "up" })

        -- Cmd+K is the session switcher by default; make it the palette
        rex.bind("cmd+k", "client.palette.toggle")
        rex.bind("cmd+s", "session.switch")

        -- ctrl+a prefix carried over from ghostty (configs/files.nix)
        rex.bind("ctrl+a>n", "client.window.new")
        rex.bind("ctrl+a>h", "client.sidebar.toggle")
        -- ctrl+a now starts a sequence; press it twice for beginning-of-line
        rex.bind("ctrl+a>ctrl+a", "pane.send_key", { key = "ctrl+a" })
      '';
    };

    # Rex doesn't watch init.lua. Skip quietly when the server isn't running.
    home.activation.rexConfigReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ -S "$HOME/Library/Application Support/rex/server.sock" ]; then
        run "${rexBin}/rex" config reload || true
      fi
    '';
  };
}
