{ pkgs, pkgs-unstable, ... }:
{
  environment.systemPackages = with pkgs; [
    #media
    #yt-dlp
    #scdl
    ffmpeg
    spotdl
    mpv
    #utils
    openvpn
    busybox
    #utils
    jmtpfs
    autorandr
    #terminal
    openssl
    udisks
    nerd-fonts.terminess-ttf
    xclip
    carapace # completions
    #desktop goodies
  ];

}
