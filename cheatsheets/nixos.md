# to update 
nix flake update git+ssh://git@github.com/ezekielenns/devenvs
# for searching 
https://discourse.nixos.org/t/what-is-the-best-way-to-search-for-packages-in-the-command-line/14908
# big notes
use `nix flake update` and then commit lock file to upgrade system
use `--refresh` on any flake commands to repull from git
generate hardware `nixos-generate-config  --show-hardware-config >> nixos/laptop-hw.nix`
build off flake: `sudo nixos-rebuild --flake '.#laptop' boot --impure`
[watch your git](https://www.reddit.com/r/NixOS/comments/tge4uu/why_flake_compile_existing_packages_from_nixpkgs/)
`nix --extra-experimental-features 'nix-command flakes' develop github:Ezekielenns/editor`

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
```
sudo nixos-rebuild switch --upgrade --impure --flake github:ezekielenns/configs#desktop  
sudo nix-channel --add https://channels.nixos.org/nixos-23.11 nixos
```


`ls | select name | input list --fuzzy | cd $in.name`
`nvim --listen ./test.pipe` fyi pipe disapares when closed 
` echo "REE" | xargs -I {} nvim --server test.pipe --remote-send ':lua print "{}"<CR>'`

## ad this this setup
`nixos-install --no-root-passwd --flake sourcehut:~sntx/flake#iovis`

# using nvim flake
`nix develop github:EzekielEnns/editor

`nix flake check`
`systemctl status "home-manager-$USER.service"`

use this to get hash info
` nix-prefetch fetchFromGitHub --url https://github.com/chrisgrieser/nvim-scissors --rev main --owner chrisgrieser --repo nvim-scissors`

setting up private flakes
`nix build ssh+git://git@github.com:username/private-repo`


to update flakes you need to do two things
- in the repo run `nix flake update` and then push that to your repo
- on your os you need to run `nix flake flake-repo` to update it locally


# how to get any repo you need
`nix-prefetch-github {owner} {repo}`


fun fact as of v24.05 nix develop envs go to all tmux sessions/ it dose some funky stuff

TODO
https://www.reddit.com/r/NixOS/comments/17ia1g8/comment/k6xcsr9/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
https://github.com/NixOS/nix/issues/8823
