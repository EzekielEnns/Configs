{...}: 
{
    imports = [
            ../configs/starship.nix
            ../configs/tmux.nix
            ../configs/git.nix
            ../configs/files.nix
    ];
    options = {};
    config = {
        home.username ="ezekielenns";
        home.homeDirectory = "/Users/ezekielenns";
        xdg.enable = true;
        programs.home-manager.enable =true;
        home.stateVersion = "23.11";
    };
}
