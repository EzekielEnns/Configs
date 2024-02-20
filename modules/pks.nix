{config,pkgs,...}:
{
  environment.systemPackages = with pkgs; [
    autorandr
    slack
    libreoffice-qt
    yt-dlp
    zoom-us
    #git
    #nodejs_latest
    helix
    jmtpfs
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
  programs.steam = {
    enable = true;
    remotePlay.openFirewall =
      true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall =
      true; # Open ports in the firewall for Source Dedicated Server
  };
}
