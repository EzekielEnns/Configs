chosen="$( echo -e "\nshutdown\nlock\nreboot\nsleep" | bemenu)"
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


