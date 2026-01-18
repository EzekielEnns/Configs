{ config
, pkgs
, lib
, inputs
, ...
}:
{

  imports = [
    ./packages.nix
    ./windowManager.nix
    ./virtualization.nix
    ./networking.nix
    ./nvim.nix
    ../configs/bash.nix
    ./shell.nix
  ];
  options = { };
  config = {
    programs.steam.enable = true;
    programs.steam.gamescopeSession.enable = true;
    services.joycond.enable = true;

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    programs.fzf = {
      fuzzyCompletion = true;
      keybindings = true;
    };
    system.stateVersion = "23.05";
    services.gnome.gnome-keyring.enable = true;
    # hard drives
    services.gvfs.enable = true;
    services.devmon.enable = true;
    nixpkgs.config.allowUnfree = true;
    # flakes
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Boot loader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.supportedFilesystems = [ "ntfs" ];
    services.udisks2.enable = true;
    # man pages
    documentation.enable = true;
    documentation.man.enable = true;
    documentation.dev.enable = true;
    # Hardware
    hardware.keyboard.qmk.enable = true;
    hardware.bluetooth.enable = true;
    #time
    time.timeZone = "Canada/Mountain";
    i18n.defaultLocale = "en_CA.UTF-8";

    services.blueman.enable = true;
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    services.printing.enable = true;
    services.libinput.enable = true;
    # Define a user account. Don't forget to set a password with ‘passwd’.
    users.users.ezekiel = {
      isNormalUser = true;
      description = "ezekiel";
      extraGroups = [
        "networkmanager"
        "wheel"
        "docker"
      ];
      packages = with pkgs; [
        firefox
        xfce.thunar
        vial
      ];
    };

    # Fonts
    fonts = {
      packages = with pkgs; [
        noto-fonts
        font-awesome
        source-han-sans
        source-han-sans
        source-han-serif
        nerd-fonts.monofur
      ];
      fontconfig = {
        enable = true;
        defaultFonts = {
          monospace = [ "Meslo LG M Regular Nerd Font Complete Mono" ];
          serif = [
            "Noto Serif"
            "Source Han Serif"
          ];
          sansSerif = [
            "Noto Sans"
            "Source Han Sans"
          ];
        };
      };
    };
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    nix.optimise.automatic = true;
    nix.settings.auto-optimise-store = true;
    nix.extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';

  };
}
