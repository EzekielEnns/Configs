{ config, pkgs, ... }:
{
  # Use existing Docker setup (should already be enabled in your config)
  # virtualisation.docker.enable = true;

  # Disable the native NixOS service
  services.open-webui.enable = false;

  # Add SearXNG service (simplified)
  # systemd.services.searxng-docker = {
  #   description = "SearXNG Search Engine Container";
  #   after = [ "docker.service" ];
  #   requires = [ "docker.service" ];
  #   wantedBy = [ "multi-user.target" ];
  #   
  #   serviceConfig = {
  #     Type = "forking";
  #     RemainAfterExit = true;
  #     TimeoutStartSec = "60s";
  #     ExecStartPre = [
  #       # Remove existing container if it exists (no pulling since you have the image)
  #       "-${pkgs.docker}/bin/docker rm -f searxng"
  #       # Create the settings directory and config file
  #       "${pkgs.coreutils}/bin/mkdir -p /var/lib/searxng"
  #       "${pkgs.writeShellScript "create-searxng-config" ''
  #         if [ ! -f /var/lib/searxng/settings.yml ]; then
  #           cat > /var/lib/searxng/settings.yml << 'EOF'
  #         use_default_settings: true
  #         
  #         server:
  #           secret_key: "changeme-please-update-searxng"
  #           limiter: false
  #           image_proxy: true
  #           port: 8080
  #           bind_address: "0.0.0.0"
  #           
  #         ui:
  #           static_use_hash: true
  #           
  #         search:
  #           safe_search: 0
  #           autocomplete: ""
  #           default_lang: ""
  #           formats:
  #             - html
  #             - json
  #             
  #         engines:
  #           - name: google
  #             disabled: false
  #           - name: bing
  #             disabled: false  
  #           - name: duckduckgo
  #             disabled: false
  #         EOF
  #         fi
  #       ''}"
  #     ];
  #     
  #     # Bind to all interfaces so Docker containers can reach it
  #     ExecStart = ''
  #       ${pkgs.docker}/bin/docker run -d \
  #         --name searxng \
  #         --restart unless-stopped \
  #         -p 0.0.0.0:8088:8080 \
  #         -v /var/lib/searxng:/etc/searxng:rw \
  #         --add-host=host.docker.internal:host-gateway \
  #         searxng/searxng:latest
  #     '';
  #     
  #     ExecStop = "${pkgs.docker}/bin/docker stop searxng";
  #     ExecStopPost = "${pkgs.docker}/bin/docker rm -f searxng";
  #   };
  # };
  #
  # # Create systemd service for Open WebUI container
  # systemd.services.open-webui-docker = {
  #   description = "Open WebUI Container";
  #   after = [ "docker.service" "searxng-docker.service" ];
  #   requires = [ "docker.service" ];
  #   wants = [ "searxng-docker.service" ];
  #   wantedBy = [ "multi-user.target" ];
  #   
  #   serviceConfig = {
  #     Type = "forking";
  #     RemainAfterExit = true;
  #     TimeoutStartSec = "60s";
  #     ExecStartPre = [
  #       # Remove existing container if it exists (no pulling since you have the image)
  #       "-${pkgs.docker}/bin/docker rm -f open-webui"
  #     ];
  #     
  #     # Open WebUI should be on port 8080
  #     ExecStart = ''
  #       ${pkgs.docker}/bin/docker run -d \
  #         --name open-webui \
  #         --restart unless-stopped \
  #         -p 127.0.0.1:8080:8080 \
  #         -e ANONYMIZED_TELEMETRY=False \
  #         -e DO_NOT_TRACK=True \
  #         -e SCARF_NO_ANALYTICS=True \
  #         -e OLLAMA_API_BASE_URL=http://host.docker.internal:11434 \
  #         -e WEBUI_AUTH=False \
  #         -e WEBUI_SECRET_KEY=super-secret-key-change-me \
  #         -e ENABLE_RAG_WEB_SEARCH=True \
  #         -e RAG_WEB_SEARCH_ENGINE=searxng \
  #         -e RAG_WEB_SEARCH_RESULT_COUNT=3 \
  #         -e RAG_WEB_SEARCH_CONCURRENT_REQUESTS=10 \
  #         -e SEARXNG_QUERY_URL=http://host.docker.internal:8088/search?q=<query> \
  #         -v /var/lib/open-webui:/app/backend/data \
  #         --add-host=host.docker.internal:host-gateway \
  #         ghcr.io/open-webui/open-webui:main
  #     '';
  #     
  #     ExecStop = "${pkgs.docker}/bin/docker stop open-webui";
  #     ExecStopPost = "${pkgs.docker}/bin/docker rm -f open-webui";
  #   };
  # };
  #
  # # Ensure the data directories exist with proper permissions
  # systemd.tmpfiles.rules = [
  #   "d /var/lib/open-webui 0755 root root -"
  #   "d /var/lib/searxng 0755 root root -"
  # ];
}
