# big notes
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


`ls | select name | input list --fuzzy | cd $in.name`
`nvim --listen ./test.pipe` fyi pipe disapares when closed 
` echo "REE" | xargs -I {} nvim --server test.pipe --remote-send ':lua print "{}"<CR>'`

## ad this this setup
`nixos-install --no-root-passwd --flake sourcehut:~sntx/flake#iovis`

# using nvim flake
`nix develop github:EzekielEnns/editor
