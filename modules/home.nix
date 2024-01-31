#TODO make this more of a home.nix setup?
{config, pkgs, ...}: 
{
    home.username ="ezekiel";
    home.homeDirectory = "/home/ezekiel";
    programs.home-manager.enable =true;
    home.stateVersion = "23.11";
    #TODO import i3 config 
}
