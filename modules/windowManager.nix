{config,pkgs,pkgs-unstable,inputs,...}:
let
  veikk_driver = (pkgs.callPackage ./veikkDriver.nix {});
in {
  # Desktop
  nixpkgs.config.permittedInsecurePackages = [
    "electron-25.9.0"
  ];
  programs.dconf.enable = true;

 environment.sessionVariables.NIXOS_OZONE_WL = "1";
programs.sway.enable=true;
  # services.xserver.displayManager.gdm= {
  #     enable = true;
  #     wayland = true;
  # };
  # services.displayManager = {
  #   autoLogin = {
  #     enable = true;
  #     user = "ezekiel";
  #   };
  # };

  environment.systemPackages = with pkgs; [
      grim # screenshot functionality
      # slurp # screenshot functionality
      wl-clipboard # wl-copy and wl-paste for copy/paste from stdin / stdout
      # mako # notification system developed by swaywm maintainer

      veikk_driver
      xournalpp
      gromit-mpx
      qbittorrent
      mpv
      font-awesome_5
      #apps
      lf
      unclutter
      feh
      i3status-rust
      swaylock
      networkmanagerapplet
      arandr
      find-cursor
      dmenu
      picom
      xss-lock
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
  services.udev.packages = [ veikk_driver ];
}
