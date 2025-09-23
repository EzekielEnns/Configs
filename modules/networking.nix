
{config,pkgs,pkgs-unstable,inputs,...}:
{

      #TODO move
      networking.hostName = "nixos";
      systemd.services.NetworkManager-wait-online.enable = false;
      # networking
      networking.networkmanager.enable = true;
      networking.wireless.userControlled.enable = true;
      networking.firewall.enable = false;
      networking.enableIPv6 = false;
}
