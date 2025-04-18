# Edit this configuration file to define what should be installed ongener
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
#sudo cp nixos/desktop/configuration.nix nixos/general.nix /etc/nixos/
#TODO get configs: kitty, i3status-rust. i3, starship, mpv, lf
# in a state where packages with app maybe home manager?
#TODO setup windows vm
{ config, pkgs,lib,inputs, ... }:
{

    imports =[
        ./packages.nix
        ./devCerts.nix
        ./windowManager.nix
        ./virtualization.nix
        ./networking.nix
        ./nvim.nix
        ../configs/scripts.nix
        ../configs/bash.nix
        ./shell.nix
    ];
    options = {};
    config = {
        programs.steam.enable =true;
        programs.steam.gamescopeSession.enable =true;
    services.joycond.enable =true;
     programs.fzf = {
        fuzzyCompletion=true;
        keybindings=true;
      };
      system.stateVersion = "23.05"; 
      services.gnome.gnome-keyring.enable = true;
      # hard drives
      services.gvfs.enable = true;
      services.devmon.enable = true;
      nixpkgs.config.allowUnfree = true;
      # flakes
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
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
      hardware.pulseaudio.enable = false;
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
        shell = pkgs.zsh;
        description = "ezekiel";
        extraGroups = [ "networkmanager" "wheel" "docker" ];
        packages = with pkgs; [ firefox xfce.thunar vial ];
      };

      # Fonts
      fonts = {
        packages = with pkgs; [
          noto-fonts
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
