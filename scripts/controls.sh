#!/usr/bin/bash
chosen="$(echo -e "media\nfile\nbluetooth\nsound\nwifi\nscreen\n" | fzf)"
#TODO open in tmux session 
COMMAND="";
case ${chosen} in
    bluetooth)
        COMMAND="bluetoothctl";;
    sound)
        COMMAND="pacmixer";;
    wifi)
        COMMAND="nmtui";;
    file)
        COMMAND="nnn";;
    media)
        COMMAND="bashmount";;
    screen)
        COMMAND="arandr";;
esac


if [[ $TERM_PROGRAM -eq "tmux" ]]; then
    tmux new -A -s "controls" -d "$COMMAND"
    tmux switch -t "controls"
else 
    tmux new -A -s "controls" \; new-window "$COMMAND"
fi 
