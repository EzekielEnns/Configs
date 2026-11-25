# The shared notes vault on the desktop (configs/notes): Syncthing as ezekiel, syncing ~/Notes
# with the Mac and the phones over Tailscale only, and an hourly git snapshot of the vault.
#
# Tailnet-only: Syncthing listens on the desktop's Tailscale address (tailscale0 is a trusted
# interface, so the firewall needs no port), with global discovery, relays, NAT traversal and
# local discovery off. The GUI is on 127.0.0.1:8384: from the Mac, `ssh -L 8385:127.0.0.1:8384
# desktop` and open http://127.0.0.1:8385. Devices and the `notes` folder are paired once in
# the GUI (notes/notes-vault.md) and kept: nothing here overrides them.
#
# Configs/ in the vault: a one-way copy of this repo's notes/ (plans, setup docs), refreshed
# whenever the desktop's checkout changes. The repo is the source: edits made to the copies in
# Obsidian are overwritten, and agents can't write there (NOTES_PROTECTED).
#
# Groceries: a photo of a handwritten list in Shared/Groceries/.inbox/ (from a phone) becomes
# Shared/Groceries/<date>.md with a checkbox per item (the photo is then deleted)
# (configs/notes/groceries.py); failures park in Shared/Groceries/.failed/.
#
# Snapshots: ~/Notes/.git, a local repo that's never pushed (Syncthing ignores .git), committed
# hourly when something changed. Undo a bad sync or a bad write with `git -C ~/Notes log -p`.
{ config, lib, pkgs, ... }:
let
  home = "/home/ezekiel";
  tailscaleIp = "100.64.96.125";
  tailscale = "${config.services.tailscale.package}/bin/tailscale"; # the CLI matching tailscaled
  snapshot = pkgs.writeShellScript "notes-snapshot" ''
    set -eu
    cd ${home}/Notes
    git=${pkgs.git}/bin/git
    if [ ! -d .git ]; then
      $git init -q
      printf '%s\n' .stversions/ .stfolder/ '.obsidian/workspace*' '.*.tmp' '*.sync-conflict-*.tmp' > .git/info/exclude
    fi
    $git add -A
    $git diff --cached --quiet && exit 0
    $git -c user.name=notes -c user.email=notes@localhost commit -q -m "snapshot $(date -Is)"
  '';
  # Grocery-list photos (configs/notes/groceries.py): a photo in Shared/Groceries/.inbox/ becomes a
  # checklist note in Shared/Groceries/, read by Bolt through llama-swap.
  groceriesInbox = "${home}/Notes/Shared/Groceries/.inbox";
  groceries = pkgs.writeShellScript "notes-groceries" ''
    exec ${pkgs.python3}/bin/python3 -I ${../configs/notes/groceries.py} ${home}/Notes \
      http://${tailscaleIp}:8080/v1 bolt ${pkgs.imagemagick}/bin/magick
  '';
  # The vault's Obsidian settings, the same on every device: these files are written from here
  # and put back whenever a phone changes one (Syncthing brings the change in, the path unit
  # below fires). Change settings here, not in the app. Plugin data, themes and snippets
  # aren't managed.
  json = name: value: (pkgs.formats.json { }).generate name value;
  obsidianSettings = {
    "app.json" = json "app.json" {
      mobileToolbarCommands = [
        "notebook-navigator:new-note"
        "app:go-back"
        "editor:toggle-checklist-status"
        "editor:undo"
      ];
      mobileQuickRibbonItem = "notebook-navigator:new-note";
      mobilePullAction = "command-palette:open";
    };
    "appearance.json" = json "appearance.json" {
      cssTheme = "Catppuccin";
      enabledCssSnippets = [ "kitty-above-bar" ];
    };
    # grocery-snap: configs/notes/grocery-snap, installed by configs/notes' activation.
    "community-plugins.json" = json "community-plugins.json" [ "notebook-navigator" "kitty" "grocery-snap" ];
    "core-plugins.json" = json "core-plugins.json" {
      file-explorer = true;
      global-search = true;
      switcher = true;
      graph = true;
      backlink = true;
      canvas = true;
      outgoing-link = true;
      tag-pane = true;
      footnotes = false;
      properties = true;
      page-preview = true;
      daily-notes = true;
      templates = true;
      note-composer = true;
      command-palette = true;
      slash-command = false;
      editor-status = true;
      bookmarks = true;
      zk-prefixer = false;
      random-note = false;
      outline = true;
      word-count = true;
      slides = false;
      audio-recorder = true;
      workspaces = false;
      file-recovery = true;
      publish = false;
      sync = true;
      bases = true;
    };
  };
  obsidianDir = "${home}/Notes/.obsidian";
  # Only rewrites a file that differs, so its own write doesn't loop through the path unit.
  obsidianApply = pkgs.writeShellScript "notes-obsidian-settings" ''
    set -eu
    [ -d ${obsidianDir} ] || exit 0
    ${lib.concatStrings (lib.mapAttrsToList (name: file: ''
      ${pkgs.diffutils}/bin/cmp -s ${file} ${obsidianDir}/${name} || install -m 644 ${file} ${obsidianDir}/${name}
    '') obsidianSettings)}
  '';
  repoNotes = "${home}/Documents/repos/configs/notes";
  mirror = pkgs.writeShellScript "notes-mirror-configs" ''
    set -eu
    [ -d ${home}/Notes ] || exit 0
    ${pkgs.rsync}/bin/rsync -a --delete --include='*/' --include='*.md' --exclude='*' \
      ${repoNotes}/ ${home}/Notes/Configs/
  '';
in
{
  services.syncthing = {
    enable = true;
    user = "ezekiel";
    group = "users";
    dataDir = home;
    configDir = "${home}/.config/syncthing";
    guiAddress = "127.0.0.1:8384";
    openDefaultPorts = false;
    overrideDevices = false;
    overrideFolders = false;
    settings.options = {
      listenAddresses = [ "tcp://${tailscaleIp}:22000" "quic://${tailscaleIp}:22000" ];
      globalAnnounceEnabled = false;
      localAnnounceEnabled = false;
      relaysEnabled = false;
      natEnabled = false;
      urAccepted = -1;
    };
  };
  # Its listeners bind the Tailscale address, so start after Tailscale is up.
  systemd.services.syncthing = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
  };

  systemd.services.notes-mirror-configs = {
    description = "Copy the Configs repo's notes into the vault";
    unitConfig.ConditionPathIsDirectory = repoNotes;
    serviceConfig = {
      Type = "oneshot";
      User = "ezekiel";
      ExecStart = mirror;
    };
  };
  systemd.paths.notes-mirror-configs = {
    wantedBy = [ "paths.target" ];
    pathConfig.PathChanged = repoNotes;
  };
  systemd.timers.notes-mirror-configs = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };

  systemd.services.notes-obsidian-settings = {
    description = "Write the vault's Obsidian settings";
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ obsidianApply ]; # reapplied when the settings change in a rebuild
    serviceConfig = {
      Type = "oneshot";
      User = "ezekiel";
      ExecStart = obsidianApply;
    };
  };
  systemd.paths.notes-obsidian-settings = {
    wantedBy = [ "paths.target" ];
    pathConfig.PathChanged = map (name: "${obsidianDir}/${name}") (lib.attrNames obsidianSettings);
  };

  # HTTPS in front of llama-swap for the phones' Grocery snap button: Android blocks plain
  # http:// from apps, so its requests never left the phone. Tailnet only, like :8080 itself.
  # Tailscale Serve only proxies to localhost and llama-swap listens on the Tailscale address,
  # so 127.0.0.1:8081 forwards to it.
  systemd.sockets.notes-model-local = {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:8081" ];
  };
  systemd.services.notes-model-local = {
    description = "Forward 127.0.0.1:8081 to llama-swap";
    serviceConfig.ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd ${tailscaleIp}:8080";
  };
  systemd.services.notes-model-https = {
    description = "Tailscale Serve HTTPS :8443 to llama-swap";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # tailscaled being up isn't Tailscale being logged in: at boot `serve` failed with
      # "unexpected state: NoState". Wait until it answers (2026-11-25).
      ExecStartPre = "${pkgs.bash}/bin/sh -c 'until ${tailscale} status >/dev/null 2>&1; do sleep 2; done'";
      TimeoutStartSec = 300;
      ExecStart = "${tailscale} serve --bg --https=8443 http://127.0.0.1:8081";
      ExecStop = "${tailscale} serve --https=8443 off";
    };
  };

  systemd.services.notes-groceries = {
    description = "Turn grocery-list photos into checklist notes";
    after = [ "llama-swap.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "ezekiel";
      ExecStart = groceries;
    };
  };
  # Syncthing writes a temp file and renames it when the photo is complete; the rename fires this.
  systemd.paths.notes-groceries = {
    wantedBy = [ "paths.target" ];
    pathConfig.PathChanged = groceriesInbox; # created by configs/notes' activation
  };

  systemd.services.notes-snapshot = {
    description = "Commit the notes vault to its local git history";
    unitConfig.ConditionPathIsDirectory = "${home}/Notes";
    serviceConfig = {
      Type = "oneshot";
      User = "ezekiel";
      ExecStart = snapshot;
    };
  };
  systemd.timers.notes-snapshot = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "2m";
    };
  };
}
