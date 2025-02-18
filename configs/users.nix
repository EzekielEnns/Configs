#actually what is used 
{...}: 
{
    imports = [
        ./i3.nix
        ./kitty.nix
        ./starship.nix
        ./git.nix
        ./tmux.nix
        ./files.nix
    ];
    options = {};
    config = {
        home.username ="ezekiel";
        home.homeDirectory = "/home/ezekiel";
        programs.home-manager.enable =true;
        home.stateVersion = "23.11";
    };
}
