{config, pkgs, ...}: 
{
    imports = [
        ../configs/starship.nix
        ../configs/tmux.nix
        ../configs/git.nix
    ];
    options = {};
    config = {
        home.username ="ezekielenns";
        home.homeDirectory = "/Users/ezekielenns";
        xdg.enable = true;
        programs.home-manager.enable =true;
        home.stateVersion = "23.11";
        /*
        # Home Manager is pretty good at managing dotfiles. The primary way to manage
#         home.file = {
# #assuming that this is a local file
#             ".screenrc".souce = dotfiles/screenrc
#         }
        */
    };
}
