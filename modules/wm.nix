{config,pkgs,inputs,...}:
let
  veikk_driver = (pkgs.callPackage ./veikk_driver.nix {});
in {
  # Desktop
  services.xserver.enable = true;
  services.xserver.desktopManager = { xterm.enable = false; };
  services.displayManager = { defaultSession = "none+i3"; };
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
  services.xserver.displayManager = {
    lightdm.enable = true;
  };

  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "ezekiel";
    };
  };

  services.xserver.windowManager.i3 = {
    enable = true;
    extraPackages = with pkgs; [
      #inputs.ytermusic
      veikk_driver
      xournalpp
      gromit-mpx
      qbittorrent
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
      lazygit
      fzf
      #for i3 status
      pipecontrol
      lm_sensors
      #mapped to workspaces or key binds
      youtube-music
      discord
      firefox
      #pdf files
      termpdfpy
      ncpamixer
    ];

  };
  services.udev.packages = [ veikk_driver ];
}
