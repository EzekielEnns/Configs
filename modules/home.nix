#TODO make this more of a home.nix setup?
{config, pkgs, ...}: 
{
    imports = [
        ./i3status-rust.nix
        ./i3.nix
        ./kitty.nix
        ./starship.nix
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
