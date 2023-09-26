#!/usr/bin/bash
chosen="$( echo -e "\ndesktop\nlaptop" | dmenu)"
#TODO open in tmux session 
COMMAND="";
case ${chosen} in
    desktop)
        cp ./desktop/configuration.nix /etc/nixos/
        cp ./general.nix /etc/nixos/ ;;
    laptop)
        cp ./laptop/configuration.nix /etc/nixos/
        cp ./general.nix /etc/nixos/ ;;
esac


