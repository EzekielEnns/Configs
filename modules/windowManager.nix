{ config
, pkgs
, pkgs-unstable
, inputs
, ...
}:
let
  veikk_driver = (pkgs.callPackage ./veikkDriver.nix { });
in
{
  # Desktop
  services.xserver.enable = true;
  services.xserver.desktopManager = {
    xterm.enable = false;
  };
  # services.displayManager = { defaultSession = "none+i3"; };
  nixpkgs.config.permittedInsecurePackages = [
    "electron-25.9.0"
  ];
  services.xserver.displayManager.setupCommands = ''
    /run/current-system/sw/bin/xset -dpms
    /run/current-system/sw/bin/xset s off
  '';
  programs.dconf.enable = true;
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
  };
  services.displayManager = {
    gdm = {
      enable = true;
    };
    autoLogin = {
      user = "ezekiel";
      enable = true;
    };
  };
  services.desktopManager.gnome.enable = true;
  services.udev.packages = [ veikk_driver ];
}
