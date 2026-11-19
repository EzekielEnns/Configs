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
  folders = [ "Inbox" "Shared" "Shared/Groceries/.inbox" "Personal" "Wife" "Agents" "Daily" ];
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
    # (its settings) stays the phone's. Enabled in the desktop's managed Obsidian settings
    # (modules/notes-sync.nix).
    # main.js gets the tailnet's MagicDNS suffix for @TAILNET@ here (kept out of the repo);
    # without a running tailscale the installed copy is left as it is.
    p="$v/.obsidian/plugins/grocery-snap"
    run mkdir -p "$p"
    cmp -s ${./grocery-snap}/manifest.json "$p/manifest.json" \
      || run install -m 644 ${./grocery-snap}/manifest.json "$p/manifest.json"
    # Activation runs with a small PATH and set -eo pipefail, so look in the known places and
    # never let a missing tailscale fail the whole activation.
    ts=""
    for c in "$(command -v tailscale || true)" /run/current-system/sw/bin/tailscale \
             /etc/profiles/per-user/$USER/bin/tailscale /Applications/Tailscale.app/Contents/MacOS/Tailscale; do
      if [ -n "$c" ] && [ -x "$c" ]; then ts="$c"; break; fi
    done
    tailnet=""
    if [ -n "$ts" ]; then
      tailnet="$({ "$ts" status --json 2>/dev/null || true; } | sed -n 's/.*"MagicDNSSuffix": *"\([^"]*\)".*/\1/p' | head -n 1)"
    fi
    if [ -n "$tailnet" ]; then
      rendered="$(mktemp)"
      sed "s/@TAILNET@/$tailnet/g" ${./grocery-snap}/main.js > "$rendered"
      cmp -s "$rendered" "$p/main.js" || run install -m 644 "$rendered" "$p/main.js"
      rm -f "$rendered"
    else
      echo "notesVault: no tailscale status, leaving grocery-snap/main.js as it is" >&2
    fi
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
