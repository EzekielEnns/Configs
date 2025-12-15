{ pkgs, pkgs-unstable, ... }:
{
  environment.systemPackages = with pkgs; [
    #media
    yt-dlp
    scdl
    ffmpeg
    mpv
    #utils
    font-awesome_5
    pulseaudio
    playerctl
    p7zip
    unrar
    openvpn
    busybox
    chromium
    tokei
    yazi
    dust
    #work
    slack
    libreoffice-qt
    zoom-us
    #utils
    jmtpfs
    autorandr
    #terminal
    termdown
    git
    vim
    wget
    fastfetch
    openssl
    pavucontrol
    udisks
    ripgrep
    nerd-fonts.terminess-ttf
    tldr
    trash-cli
    unzip
    xclip
    carapace # completions
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
