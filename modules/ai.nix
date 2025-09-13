{ config, pkgs,  ... }:
{
  # Enable Podman
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;  # Creates docker alias for podman
    defaultNetwork.settings.dns_enabled = true;
  };

  # Disable the native NixOS service
  services.open-webui.enable = false;

  # Create systemd service for Open WebUI container
  systemd.services.open-webui-podman = {
    description = "Open WebUI Container";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "forking";
      RemainAfterExit = true;
      ExecStartPre = [
        # Pull the latest image
        "${pkgs.podman}/bin/podman pull ghcr.io/open-webui/open-webui:main"
        # Remove existing container if it exists
        "-${pkgs.podman}/bin/podman rm -f open-webui"
      ];
      
      ExecStart = ''
        ${pkgs.podman}/bin/podman run -d \
          --name open-webui \
          --restart unless-stopped \
          -p 127.0.0.1:8080:8080 \
          -e ANONYMIZED_TELEMETRY=False \
          -e DO_NOT_TRACK=True \
          -e SCARF_NO_ANALYTICS=True \
          -e OLLAMA_API_BASE_URL=http://host.containers.internal:11434 \
          -e WEBUI_AUTH=False \
          -v /var/lib/open-webui:/app/backend/data \
          --add-host=host.containers.internal:host-gateway \
          ghcr.io/open-webui/open-webui:main
      '';
      
      ExecStop = "${pkgs.podman}/bin/podman stop open-webui";
      ExecStopPost = "${pkgs.podman}/bin/podman rm -f open-webui";
    };
  };

  # Ensure the data directory exists with proper permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/open-webui 0755 root root -"
  ];

  # Optional: Auto-update service (runs weekly)
  systemd.services.open-webui-update = {
    description = "Update Open WebUI Container";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "update-open-webui" ''
        ${pkgs.podman}/bin/podman pull ghcr.io/open-webui/open-webui:main
        ${pkgs.systemd}/bin/systemctl restart open-webui-podman
      '';
    };
  };

  systemd.timers.open-webui-update = {
    description = "Update Open WebUI Container Weekly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };
}
