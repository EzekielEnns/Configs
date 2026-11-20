{ config, lib, pkgs, ... }:
# LikeC4 (https://likec4.dev): architecture diagrams as code, one live-reloading server for every
# project in the workspace (each folder holding a likec4.config.json shows up as its own project).
# Agents edit the .c4 files; the browser picks the change up without a restart.
#
# The workspace is a local repo on this machine, not part of this public one: the models describe
# private setups and work systems. nixpkgs has no likec4, so the workspace's own package-lock pins
# it; run `npm ci` there once (the unit waits for node_modules). The server is started with no
# OPENAI_API_KEY, which keeps LikeC4's AI features (they send the model to OpenAI) off.
let
  cfg = config.services.likec4;
in
{
  options.services.likec4 = {
    enable = lib.mkEnableOption "the LikeC4 diagram server";
    workspace = lib.mkOption {
      type = lib.types.str;
      description = "The LikeC4 workspace (a checkout with node_modules/likec4 installed).";
    };
    user = lib.mkOption { type = lib.types.str; };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      description = "Address to serve on; a Tailscale address keeps it off the LAN.";
    };
    port = lib.mkOption { type = lib.types.port; default = 5180; };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.likec4 = {
      description = "LikeC4 diagram server";
      wantedBy = [ "multi-user.target" ];
      # The Tailscale address appears some time after tailscaled starts; until then the bind
      # fails and the unit retries.
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "tailscaled.service" ];
      unitConfig = {
        ConditionPathExists = "${cfg.workspace}/node_modules/likec4/bin/likec4.mjs";
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        User = cfg.user;
        WorkingDirectory = cfg.workspace;
        ExecStart = "${pkgs.nodejs}/bin/node ${cfg.workspace}/node_modules/likec4/bin/likec4.mjs start --listen ${cfg.listenAddress} --port ${toString cfg.port}";
        Restart = "always";
        RestartSec = 10;
      };
    };
  };
}
