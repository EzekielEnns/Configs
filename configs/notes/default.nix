# The shared notes vault (~/Notes), home-manager side, both machines: the tools (Pi's notes
# extension, `notes`, `notes-mcp`), the vault's folders, and on the Mac, Syncthing. The
# desktop's Syncthing and hourly snapshots are NixOS (modules/notes-sync.nix); Claude Code's
# registration is in configs/claude.nix.
#
# Sync is tailnet-only: Syncthing listens on this machine's Tailscale address, with global
# discovery, relays, NAT traversal and local discovery off, and its GUI on 127.0.0.1:8384.
# Devices and the `notes` folder are paired once in the GUI (notes/notes-vault.md) and kept:
# nothing here overrides them.
{ lib, pkgs, ... }:
let
  notesTools = pkgs.callPackage ./package.nix { };
  folders = [ "Inbox" "Inbox/Groceries" "Shared" "Personal" "Wife" "Agents" "Daily" ];
  # Syncthing's ignore file isn't synced, so every machine writes its own (the phone's is set
  # in the app). .git is the desktop's snapshot history.
  stignore = pkgs.writeText "stignore" ''
    .git
    .obsidian/workspace*
    .trash
  '';
in
{
  home.packages = [ notesTools ];
  home.file.".pi/agent/extensions/notes".source = "${notesTools}/lib/notes";

  # Folders and the agent rules, only where missing: the vault is the people's, synced from
  # the phones, so nothing here overwrites a note.
  home.activation.notesVault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    v="$HOME/Notes"
    run mkdir -p ${lib.concatMapStringsSep " " (f: ''"$v/${f}"'') folders} "$HOME/.local/state/notes"
    [ -e "$v/AGENTS.md" ] || run install -m 644 ${notesTools}/lib/notes/AGENTS.md "$v/AGENTS.md"
    run install -m 644 ${stignore} "$v/.stignore"
    # Grocery snap (grocery-snap/main.js), the phones' cart button: .obsidian/ syncs, so it
    # reaches both phones. Copied only when changed, so Syncthing doesn't churn; data.json
    # (its settings) stays the phone's. Enabled once in .obsidian/community-plugins.json.
    p="$v/.obsidian/plugins/grocery-snap"
    run mkdir -p "$p"
    for f in main.js manifest.json; do
      cmp -s ${./grocery-snap}/$f "$p/$f" || run install -m 644 ${./grocery-snap}/$f "$p/$f"
    done
  '';

  services.syncthing = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    guiAddress = "127.0.0.1:8384";
    overrideDevices = false;
    overrideFolders = false;
    settings.options = {
      listenAddresses = [ "tcp://100.71.237.57:22000" "quic://100.71.237.57:22000" ]; # the Mac's Tailscale IP
      globalAnnounceEnabled = false;
      localAnnounceEnabled = false;
      relaysEnabled = false;
      natEnabled = false;
      urAccepted = -1;
    };
  };
}
