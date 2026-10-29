# The shared notes vault on the desktop (configs/notes): Syncthing as ezekiel, syncing ~/Notes
# with the Mac and the phones over Tailscale only, and an hourly git snapshot of the vault.
#
# Tailnet-only: Syncthing listens on the desktop's Tailscale address (tailscale0 is a trusted
# interface, so the firewall needs no port), with global discovery, relays, NAT traversal and
# local discovery off. The GUI is on 127.0.0.1:8384: from the Mac, `ssh -L 8385:127.0.0.1:8384
# desktop` and open http://127.0.0.1:8385. Devices and the `notes` folder are paired once in
# the GUI (notes/notes-vault.md) and kept: nothing here overrides them.
#
# Snapshots: ~/Notes/.git, a local repo that's never pushed (Syncthing ignores .git), committed
# hourly when something changed. Undo a bad sync or a bad write with `git -C ~/Notes log -p`.
{ pkgs, ... }:
let
  home = "/home/ezekiel";
  tailscaleIp = "100.64.96.125";
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
