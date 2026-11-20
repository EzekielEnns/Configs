{ config, lib, pkgs, ... }:
# LikeC4 (https://likec4.dev): architecture diagrams as code. Two services over one workspace:
#   - the diagram server, live-reloading, every project in the workspace (each folder holding a
#     likec4.config.json is its own project); agents edit the .c4 files, the browser follows.
#   - the LikeC4 MCP (read-only: search, read views and elements, follow relationships), over
#     HTTP at /mcp, registered for Claude on both machines in configs/claude.nix.
# Both are tailnet-only: the MCP binds every interface and the firewall is off on this host, so
# the units only accept traffic from Tailscale addresses and this machine.
#
# The workspace is kept like the notes vault (modules/notes-sync.nix): synced with the Mac by
# Syncthing over Tailscale (a `diagrams` folder, paired once in the GUI; node_modules and .git
# stay here), and snapshotted hourly into a local git repo that's never pushed. It's not part of
# this public repo: the models describe private setups and work systems.
#
# nixpkgs has no likec4, so the workspace's own package-lock pins it; run `npm ci` there once
# (the units wait for node_modules). No OPENAI_API_KEY reaches them, which keeps LikeC4's AI
# features (they send the model to OpenAI) off.
let
  cfg = config.services.likec4;
  likec4 = "${pkgs.nodejs}/bin/node ${cfg.workspace}/node_modules/likec4/bin/likec4.mjs";
  stignore = pkgs.writeText "stignore" ''
    node_modules
    dist
    .git
  '';
  snapshot = pkgs.writeShellScript "likec4-snapshot" ''
    set -eu
    cd ${cfg.workspace}
    git=${pkgs.git}/bin/git
    if [ ! -d .git ]; then
      $git init -q
    fi
    printf '%s\n' node_modules/ dist/ .stversions/ .stfolder/ '*.sync-conflict-*' > .git/info/exclude
    $git add -A
    $git diff --cached --quiet && exit 0
    $git -c user.name=diagrams -c user.email=diagrams@localhost commit -q -m "snapshot $(date -Is)"
  '';
  common = {
    wantedBy = [ "multi-user.target" ];
    # The Tailscale address appears some time after tailscaled starts.
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "tailscaled.service" ];
    unitConfig = {
      ConditionPathExists = "${cfg.workspace}/node_modules/likec4/bin/likec4.mjs";
      StartLimitIntervalSec = 0;
    };
    serviceConfig = {
      User = cfg.user;
      WorkingDirectory = cfg.workspace;
      Restart = "always";
      RestartSec = 10;
      IPAddressDeny = "any";
      IPAddressAllow = [ "localhost" "100.64.0.0/10" "fd7a:115c:a1e0::/48" ];
    };
  };
in
{
  options.services.likec4 = {
    enable = lib.mkEnableOption "the LikeC4 diagram server and MCP";
    workspace = lib.mkOption {
      type = lib.types.str;
      description = "The LikeC4 workspace (with node_modules/likec4 installed).";
    };
    user = lib.mkOption { type = lib.types.str; };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      description = "Address for the diagram server; a Tailscale address keeps it off the LAN.";
    };
    port = lib.mkOption { type = lib.types.port; default = 5180; };
    mcpPort = lib.mkOption { type = lib.types.port; default = 33335; };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.likec4 = lib.recursiveUpdate common {
      description = "LikeC4 diagram server";
      serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/install -m 644 ${stignore} ${cfg.workspace}/.stignore";
      serviceConfig.ExecStart = "${likec4} start --listen ${cfg.listenAddress} --port ${toString cfg.port}";
    };

    systemd.services.likec4-mcp = lib.recursiveUpdate common {
      description = "LikeC4 MCP (read-only)";
      serviceConfig.ExecStart = "${likec4} mcp --http --port ${toString cfg.mcpPort} ${cfg.workspace}";
    };

    systemd.services.likec4-snapshot = {
      description = "Snapshot the LikeC4 workspace into its local git history";
      unitConfig.ConditionPathIsDirectory = cfg.workspace;
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        ExecStart = snapshot;
      };
    };
    systemd.timers.likec4-snapshot = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };
  };
}
