{config,pkgs,pkgs-unstable,inputs,...}:
{
  environment.systemPackages = with pkgs; [

    chromium
    #work
    du-dust
    pkgs-unstable.jetbrains.rider
    dotnet-sdk_8 
    msbuild
    mono
    slack
    libreoffice-qt
    zoom-us
    #utils
    jmtpfs
    autorandr
    #others
    #flatpak 
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
    # protonup-ng
    # steam
    # steam-run
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

  # programs.steam = {
  #   enable = true;
  #   remotePlay.openFirewall = true; 
  #   dedicatedServer.openFirewall = true; 
  # };
}
