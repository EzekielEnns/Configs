#wtf is this i dont think it works
{config, pkgs, ...}: 
{
    imports = [
        ../configs/i3status-rust.nix
        ../configs/i3.nix
        ../configs/kitty.nix
        ../configs/starship.nix
        ../configs/tmux.nix
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
