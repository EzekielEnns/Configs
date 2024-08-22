{ config, pkgs, ... }:

{
  #networking.hostName = "laptop";
  hardware.system76.enableAll = true;
  services.power-profiles-daemon.enable = false;
}
