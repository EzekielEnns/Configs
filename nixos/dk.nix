{ config, pkgs,  ... }:
{
  networking.interfaces.enp6s0.wakeOnLan = {
    enable = true;
  };

  networking.networkmanager.enable = true;
  # disables etho in network manager
  networking.networkmanager.unmanaged = ["enp6s0"];

  services.xserver.videoDrivers = ["nvidia"];
  hardware.steam-hardware.enable =true;
  hardware.graphics.enable32Bit=true;
  hardware.nvidia = {

    # Modesetting is needed most of the time
    modesetting.enable = true;

	# Enable power management (do not disable this unless you have a reason to).
	# Likely to cause problems on laptops and with screen tearing if disabled.
	powerManagement.enable = true;

    # Use the open source version of the kernel module ("nouveau")
	# Note that this offers much lower performance and does not
	# support all the latest Nvidia GPU features.
	# You most likely don't want this.
    # Only available on driver 515.43.04+
    open = false;

    # Enable the Nvidia settings menu,
	# accessible via `nvidia-settings`.
    nvidiaSettings = true;
    #https://nixos.wiki/wiki/Nvidia
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  services.ollama = {
    enable = true;
    acceleration = "cuda";
    host = "0.0.0.0";
  };
    # services.open-webui = {
    #     enable = true;
    #     port = 8080;  # Default port is 8080, you can change it if needed
    #     environment = {
    #         ANONYMIZED_TELEMETRY = "False";
    #         DO_NOT_TRACK = "True";
    #         SCARF_NO_ANALYTICS = "True";
    #         OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";  # Points to your local Ollama instance
    #         WEBUI_AUTH = "False";  # Optional: disable authentication
    #     };
    # };
  hardware.opengl = {
    enable = true;
  };

services.nginx = {
  enable = true;
  recommendedGzipSettings = true;
  recommendedOptimisation = true;
  recommendedProxySettings = true;
  recommendedTlsSettings = true;
  
  # Just the virtual host for the LLM interface (Open WebUI)
  virtualHosts."192.168.1.6" = {
    locations = {
      "/" = {
        proxyPass = "http://localhost:8080";  # Open WebUI runs on HTTP by default
        proxyWebsockets = true;  # Important for real-time interactions in the UI
      };
    };
  };
};

# Don't forget to allow the necessary ports in your firewall
networking.firewall.allowedTCPPorts = [ 80 443 11434 ];  # ← Added 11434

}

