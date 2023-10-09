{ config, pkgs, ... }:

{ swapDevices = [ {
    device = "/var/lib/swapfile";
    size = 11*1024;
  } ];
}
