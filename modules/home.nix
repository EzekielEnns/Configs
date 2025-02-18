{...}: 
{
    imports = [
        ../configs/i3status-rust.nix
        ../configs/i3.nix
        ../configs/starship.nix
        ../configs/tmux.nix
        ../configs/files.nix
    ];
    options = {};
    config = {
        home.username ="ezekiel";
        home.homeDirectory = "/home/ezekiel";
        programs.home-manager.enable =true;
        home.stateVersion = "23.11";
    };
}
