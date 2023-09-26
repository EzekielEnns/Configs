# TODO
- [ ] add common flatpaks nixconfig 
- [ ] add simlinks to config locations via bash script 
- [ ] make alpha always the main page for nvim
- [ ] remove annoying movment in i3
- [ ] move away from cording 
- [ ] add buttons for neoformat, maybe all buffers, 
- [ ] add hook up for yaml
- [ ] add button for telescope
- [ ] fix tmux to start in nix-shell that i normally use 
- [ ] add button for lsp restart or add a watcher 
- [ ] add deveriation for vktablet 

change the file structure a bit to match the right stuff.
add more packages

https://discourse.nixos.org/t/neovim-lua-configuration/22470/7
https://nix.dev/tutorials/first-steps/ad-hoc-shell-environments

https://support.system76.com/articles/system76-software/
https://support.system76.com/articles/system76-driver/
https://nixos.wiki/wiki/Neovim
https://discourse.nixos.org/t/neovim-lua-configuration/22470/7
https://search.nixos.org/options?show=programs.neovim.configure&type=packages&query=neovim
https://nixos.wiki/wiki/Command_Shell

really good reffernce:
http://ghedam.at/15978/an-introduction-to-nix-shell

nix-shell -p protonmail-bridge
add qmk stuff,
add cd \*\* \<tab\>


kay in start up bash shell run this:
sudo nixos-rebuild switch -I nixos-config=configs/nixos/configuration.nix

use soft links (hard links are minor copies)
ln -s ~/.dotfiles/nvim/init.vim ~/.config/nvim/init.vim

nix-shell --command 'zellij  --layout ~/Documents/configs/zellij/work.kdl -c ~/Documents/configs/zellij/config.kdl'

use `bluetoothctl devices` and then split on middle and use `bluetoothctl connect ID`

add  systemctl hibernate
and systemctl suspend
to power menu


# big notes
delets old generations
`sudo nix-collect-garbage --delete-older-than 1d`
```
nix --extra-experimental-features nix-command profile history --profile /nix/var/nix/profiles/system

sudo nix  --extra-experimental-features nix-command profile wipe-history --profile /nix/var/nix/profiles/system --older-than 14d


```
regens hardware .nix
`nixos-generate-config `
NOTE nixos requries configuration.nix to be the name
used this to fix bug
```
sudo rm -rf /nix/var/nix/profiles/system-profiles/nixos-config\=configs/
sudo nixos-rebuild boot
sudo nixos-rebuild switch -I nixos-config=/etc/nixos/configuration.nix 
sudo nixos-rebuild switch

```


`ls | select name | input list --fuzzy | cd $in.name`
