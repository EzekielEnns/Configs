#!/usr/bin/bash 
set -x
wp=`find ~/Documents/ -maxdepth 3 -type f -name 'shell.nix' |  fzf` 
( cd $(dirname $wp) ; nix-shell --command "kitty --detach --session ~/Documents/configs/kitty/work.conf" ) 
