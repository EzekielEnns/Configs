{config,pkgs,pkgs-unstable,inputs,...}:
{
  environment.systemPackages = with pkgs; [
    pulseaudio #for volumn
    playerctl
    p7zip
    openvpn
    busybox
    chromium
    tokei
    yazi
    du-dust
    #work
    pkgs.jetbrains.jdk
    pkgs.jetbrains.rider
    pkgs.jetbrains.gateway
    dotnet-sdk_8 
    msbuild
    mono
    slack
    libreoffice-qt
    zoom-us
    #utils
    jmtpfs
    autorandr
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
    carapace #complication
    #gaming 
    steam
    #steam-run
    #desktop goodies
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr 
    xorg.libX11
    xorg.libX11.dev
    xorg.libxcb
    xorg.libXft
    xorg.libXinerama
    xorg.xinit
    xorg.xinput
    screenkey
    simplescreenrecorder
    nix-prefetch-github
  ];

  programs.steam = {
    gamescopeSession.enable = true;
    enable = true;
    remotePlay.openFirewall = true; 
    dedicatedServer.openFirewall = true; 
  };
}
