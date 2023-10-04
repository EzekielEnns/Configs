#!/usr/bin/bash
chosen="$( echo -e "\nshutdown\nlock\nreboot\nsleep" | dmenu)"
#TODO open in tmux session 
COMMAND="";
case ${chosen} in
    shutdown)
        shutdown now;;
    lock)
        systemctl suspend;;
    reboot)
        reboot;;
    sleep)
        systemctl hibernate;;
esac


