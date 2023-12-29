set -x
wp=`find ~/Documents/ -maxdepth 3 -type f -name 'default.nix' |  fzf` || exit
( cd $(dirname $wp) ; nix develop github:EzekielEnns/editor --refresh --impure \
    --command bash -c "nix-shell --command 'kitty --detach --session ~/.config/kitty/work.conf'" ) 
