set -x
wp=`find ~/Documents/ -maxdepth 3 -type f -name 'default.nix' |  fzf` || exit
( cd $(dirname $wp) ; NIXPKGS_ALLOW_UNFREE=1 nix-shell --command 'kitty --detach --session ~/.config/kitty/work.conf' )
#sleep 1
