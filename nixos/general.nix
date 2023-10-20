# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
#sudo cp nixos/desktop/configuration.nix nixos/general.nix /etc/nixos/

{ config, pkgs, ... }:
let
  unstableTarball = fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  unstable = import unstableTarball { };
  finder = pkgs.writeShellApplication {
    name = "finder";
    runtimeInputs = [ pkgs.fzf ];
    text = ./../scripts/finder.sh;
  };
  men_bluetooth = pkgs.writeShellApplication {
    name = "men_bluetooth";
    runtimeInputs = [ pkgs.dmenu pkgs.bluez ];
    text = ./../scripts/bluetooth.sh;
  };
#  waybar-custom-cpu = pkgs.writeTextFile {
#    name = "waybar-custom-cpu";
#    destination = "/bin/waybar-custom-cpu";
#    executable = true;
#    text = ./waybar-custom-cpu.sh;
#  };
  #simlink?
  #men_power = pkgs.writeShellScriptBin "men_power" (builtins.readFile ./../scripts/powermenu.sh);
  men_power = pkgs.writeTextFile {
    name = "men_power";
    destination = "/bin/men_power";
    executable = true;
    text = ./../scripts/powermenu.sh;
  };
in {

  # flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # virt 
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "user-with-access-to-virtualbox" ];

  networking.hostName = "nixos";
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];
  services.udisks2.enable = true;

  # man pagaes
  documentation.enable = true;
  documentation.man.enable = true;
  documentation.dev.enable = true;

  # Hardware
  hardware.keyboard.qmk.enable = true;
  hardware.bluetooth.enable = true;

  # networking
  networking.networkmanager.enable = true;
  networking.wireless.userControlled.enable = true;
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
  networking.enableIPv6 = false;

  # Set your time zone.
  time.timeZone = "America/Halifax";
  # Select internationalisation properties.
  i18n.defaultLocale = "en_CA.UTF-8";

  # Desktop
  services.xserver.enable = true;
  services.xserver.desktopManager = { xterm.enable = false; };
  services.xserver.displayManager = { defaultSession = "none+i3"; };

  services.xserver.windowManager.i3 = {
    enable = true;
    extraPackages = with pkgs; [
      finder
      men_bluetooth
      men_power
      qbittorrent
      unstable.mpv
      unstable.w3m
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
      #terminal
      starship
      #zellij
      #alacritty
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
    ];

  };
  programs.dconf.enable = true;
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };
  services.xserver.displayManager = {
    lightdm.enable = true;
    autoLogin = {
      enable = true;
      user = "ezekiel";
    };
  };

  # Enable sound with pipewire.
  services.blueman.enable = true;
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };
  # Enable CUPS to print documents.
  services.printing.enable = true;
  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;
  services.openssh.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.ezekiel = {
    isNormalUser = true;
    description = "ezekiel";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ firefox xfce.thunar vial ];
  };

  # Packages
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  # steam
  nixpkgs.config.allowUnfreePredicate =
    (pkg: builtins.elem (builtins.parseDrvName pkg.name).name [ "steam" ]);
  nix.settings = {
    substituters = [ "https://nix-gaming.cachix.org" ];
    trusted-public-keys = [
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    ];
  };
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    finder
    men_power
    carapace
    #others
    flatpak # authy
    celluloid # gui mpv
    #utils
    git
    vim
    wget
    neofetch
    openssl
    pavucontrol
    udisks
    ripgrep
    #gaming 
    protonup-ng
    steam
    steam-run
    #terminal
    terminus-nerdfont
    tldr
    trash-cli
    unzip
    xclip
    virt-manager
    virtualbox
    #desktop goodies
    xdg-desktop-portal-gtk
    xorg.libX11
    xorg.libX11.dev
    xorg.libxcb
    xorg.libXft
    xorg.libXinerama
    xorg.xinit
    xorg.xinput

  ];
  programs.steam = {
    enable = true;
    remotePlay.openFirewall =
      true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall =
      true; # Open ports in the firewall for Source Dedicated Server
  };
  virtualisation.libvirtd.enable = true;
  services.flatpak.enable = true;
  services.dbus.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  security.polkit.enable = true;
  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart =
          "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
    extraConfig = ''
      DefaultTimeoutStopSec=10s
    '';
  };

  # Fonts
  fonts = {
    fonts = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      font-awesome
      source-han-sans
      source-han-sans-japanese
      source-han-serif-japanese
      (nerdfonts.override { fonts = [ "Monofur" ]; })
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "Meslo LG M Regular Nerd Font Complete Mono" ];
        serif = [ "Noto Serif" "Source Han Serif" ];
        sansSerif = [ "Noto Sans" "Source Han Sans" ];
      };
    };
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;
  #system.autoUpgrade.enable = true;
  #system.autoUpgrade.allowReboot = true;
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}
