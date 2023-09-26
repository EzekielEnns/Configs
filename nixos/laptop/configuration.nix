{ config, pkgs, ... }:

{

  hardware.system76.enableAll = true;
  imports = [ 
    ./hardware-configuration.nix
    ./general.nix
  ];
}
