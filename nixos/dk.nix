{ config, pkgs, ... }:

{
  networking.interfaces.enp6s0.wakeOnLan = {
    enable = true;
  };

  networking.networkmanager.enable = true;
  # disables etho in network manager
  networking.networkmanager.unmanaged = ["enp6s0"];

  services.xserver.videoDrivers = ["nvidia"];
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

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # services.nginx = {
  #   enable = true;
  #   recommendedGzipSettings = true;
  #   recommendedOptimisation = true;
  #   recommendedProxySettings = true;
  #   recommendedTlsSettings = true;
  #   virtualHosts."192.168.0.105:5001" = {
  #     locations = {
  #        "/" = {
  #          proxyPass = "https://localhost:5001";
  #          #websocket support should work even if not websocket
  #          proxyWebsockets = true;
  #       };
  #     };
  #   };
  #   virtualHosts."192.168.0.105" = {
  #     locations = {
  #        "/" = {
  #          proxyPass = "https://localhost:3000";
  #       };
  #        "/hubs" = {
  #          proxyPass = "https://localhost:5001/hubs";
  #          proxyWebsockets = true;
  #       };
  #     };
  #   };
  # };

}

