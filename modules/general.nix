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
        ./pks.nix
        ./devCerts.nix
        ./wm.nix
        ./virtualization.nix
        ./nvim.nix
        ../configs/scripts.nix
        ../configs/bash.nix
    ];
    options = {};
    config = {
      system.stateVersion = "23.05"; # Did you read the comment?

      # hard drives
      services.gvfs.enable = true;
      services.devmon.enable = true;
      nixpkgs.config.allowUnfree = true;
      # flakes
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      # virt 
      networking.hostName = "nixos";
      systemd.services.NetworkManager-wait-online.enable = false;
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
      # networking
      networking.networkmanager.enable = true;
      networking.wireless.userControlled.enable = true;
      networking.firewall.enable = false;
      networking.enableIPv6 = false;
      #time
      time.timeZone = "Canada/Mountain";
      i18n.defaultLocale = "en_CA.UTF-8";

      # Enable sound with pipe wire.
      services.blueman.enable = true;
      sound.enable = true;
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
      services.openssh.enable = true;
      # Define a user account. Don't forget to set a password with ‘passwd’.
      users.users.ezekiel = {
        isNormalUser = true;
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

      #xdg.portal.config.common.default = "*";

      # security.polkit.enable = true;
      # systemd = {
      #   user.services.polkit-gnome-authentication-agent-1 = {
      #     description = "polkit-gnome-authentication-agent-1";
      #     wantedBy = [ "graphical-session.target" ];
      #     wants = [ "graphical-session.target" ];
      #     after = [ "graphical-session.target" ];
      #     serviceConfig = {
      #       Type = "simple";
      #       ExecStart =
      #         "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      #       Restart = "on-failure";
      #       RestartSec = 1;
      #       TimeoutStopSec = 10;
      #     };
      #   };
      #   extraConfig = ''
      #     DefaultTimeoutStopSec=10s
      #   '';
      # };
    # system.autoUpgrade = {
    #     enable = true;
    #     flake = inputs.self.outPath;
    #     flags = [
    #       "--update-input"
    #       "nixpkgs"
    #       "--no-write-lock-file"
    #       "-L" # print build logs
    #     ];
    #     dates = "8:00";
    #     randomizedDelaySec = "45min";
    #   };

      # Copy the NixOS configuration file and link it from the resulting system
      # (/run/current-system/configuration.nix). This is useful in case you
      # accidentally delete configuration.nix.
      #system.copySystemConfiguration = true;
      #system.autoUpgrade.enable = true;
      #system.autoUpgrade.channel = "https://channels.nixos.org/nixos-23.11";
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
    };
}
