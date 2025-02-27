{pkgs,pkgs-unstable,...}:
{
  environment.systemPackages = with pkgs; [
    pkgs-unstable.ghostty
    pulseaudio 
    playerctl
    p7zip
    unrar
    openvpn
    busybox
    chromium
    tokei
    yazi
    du-dust
    #work
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
    carapace #completions
    #gaming 
    steam
    #desktop goodies
    xdg-desktop-portal-gtk
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
    enable = true;
    remotePlay.openFirewall = true; 
    dedicatedServer.openFirewall = true; 
  };
}
