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
  # services.displayManager = {
  #   lightdm.enable = true;
  # };
  services.xserver.displayManager.gdm = {
    enable = true;
    autoLogin = {
      user = "ezekiel";
      enable = true;
    };
  };

  # services.displayManager = {
  #   autoLogin = {
  #     enable = true;
  #     user = "ezekiel";
  #   };
  # };
  # services.displayManager.defaultSession = "gnome";
  services.desktopManager.gnome.enable = true;
  services.xserver.windowManager.i3 = {
    enable = false;
    extraPackages = with pkgs; [
      #inputs.ytermusic
      veikk_driver
      xournalpp
      gromit-mpx
      #TODO find a new torrent
      #qbittorrent
      mpv
      font-awesome_5
      #apps
      lf
      i3-cycle-focus
      unclutter
      maim
      feh
      i3status-rust
      i3lock
      networkmanagerapplet
      arandr
      find-cursor
      dmenu
      picom
      xss-lock
      lightdm
      starship
      kitty
      fzf
      #for i3 status
      pipecontrol
      ncpamixer
      lm_sensors
      #mapped to workspaces or key binds
      pkgs-unstable.youtube-music
      discord
      firefox
    ];

  };
  services.udev.packages = [ veikk_driver ];
}
