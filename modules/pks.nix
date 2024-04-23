{config,pkgs,...}:
{
  environment.systemPackages = with pkgs; [
    #work
    jetbrains.rider
    dotnet-sdk_8 
    msbuild
    slack
    libreoffice-qt
    zoom-us
    #utils
    jmtpfs
    autorandr
    #others
    flatpak 
    #terminal
    yt-dlp
    termdown
    git
    vim
    wget
    neofetch
    openssl
    pavucontrol
    udisks
    ripgrep
    terminus-nerdfont
    tldr
    trash-cli
    unzip
    xclip
    carapace #completation
    #gaming 
    protonup-ng
    steam
    steam-run
    #vertiaulization
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

  # TODO fix this https://nixos.wiki/wiki/Steam
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
