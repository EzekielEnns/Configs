#!/usr/bin/bash 
set -x
wp=`find ~/Documents/ -maxdepth 3 -type f -name 'default.nix' |  fzf` || exit
( cd $(dirname $wp) ; nix develop github:EzekielEnns/editor --command bash -c "nix-shell --command 'kitty --detach --session ~/Documents/configs/kitty/work.conf'" ) 
