{config,pkgs,pkgs-unstable,inputs,...}:
let
  veikk_driver = (pkgs.callPackage ./veikkDriver.nix {});
  swayConfig = pkgs.writeText "greetd-sway-config" ''
    # `-l` activates layer-shell mode. Notice that `swaymsg exit` will run after gtkgreet.
    exec "${pkgs.greetd.gtkgreet}/bin/gtkgreet -l; swaymsg exit"
    bindsym Mod4+shift+e exec swaynag \
      -t warning \
      -m 'What do you want to do?' \
      -b 'Poweroff' 'systemctl poweroff' \
      -b 'Reboot' 'systemctl reboot'
  '';
in {
  # Desktop
  nixpkgs.config.permittedInsecurePackages = [
    "electron-25.9.0"
  ];
  programs.dconf.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  # services.displayManager = {
  #     autoLogin = {
  #         enable = true;
  #         user = "ezekiel";
  #     };
  # };

    programs.sway = {
  enable = true;
    wrapperFeatures.gtk = true; # so that gtk works properly
        extraPackages = with pkgs; [
swaylock
      grim # screenshot functionality
      # slurp # screenshot functionality
      wl-clipboard # wl-copy and wl-paste for copy/paste from stdin / stdout
      # mako # notification system developed by swaywm maintainer
      bemenu
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
    };
  services.udev.packages = [ veikk_driver ];

  services.greetd = {
      enable = true;
      settings = rec {
          initial_session = {
              command = "${pkgs.sway}/bin/sway";
              user = "ezekiel";
          };
          default_session = initial_session;
      };
  };
}
