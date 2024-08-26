{config, pkgs, ...}: 
{
    imports = [
        ./sway.nix
        ./kitty.nix
        ./starship.nix
        ./git.nix
        ./tmux.nix
    ];
    options = {};
    config = {
        home.username ="ezekiel";
        home.homeDirectory = "/home/ezekiel";
        programs.home-manager.enable =true;
        home.stateVersion = "23.11";
    };
    #TODO import i3 config 
}
