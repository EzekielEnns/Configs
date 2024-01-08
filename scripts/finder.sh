set -x
wp=`find ~/Documents/ -maxdepth 3 -type f -name 'default.nix' |  fzf` || exit
( cd $(dirname $wp) ; nix-shell --command 'kitty --detach --session ~/.config/kitty/work.conf' ) 
