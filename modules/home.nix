{config, pkgs, ...}: 
{
    imports = [
        ../configs/i3status-rust.nix
        ../configs/i3.nix
        ../configs/kitty.nix
        ../configs/starship.nix
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
