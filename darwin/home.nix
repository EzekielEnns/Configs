{config, pkgs, ...}: 
{
    imports = [
        ../configs/kitty.nix
        ../configs/starship.nix
        ../configs/tmux.nix
        ../configs/git.nix
    ];
    options = {};
    config = {
        home.username ="ezekiel";
        home.homeDirectory = "/Users/ezekielenns";
        programs.home-manager.enable =true;
        home.stateVersion = "23.11";
        /*
        # Home Manager is pretty good at managing dotfiles. The primary way to manage
        home.file = {
#assuming that this is a local file
            ".screenrc".souce = dotfiles/screenrc
        }
        */
    };
}
