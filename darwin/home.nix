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
        home.file.".ideavimrc" = {source =./../misc/.ideavimrc; recursive=true;};
        xdg.enable = true;
        programs.home-manager.enable =true;
        home.stateVersion = "23.11";
        programs.alacritty = {
            enable = true;
            settings = {
                env = {
                    TERM = "alacritty";
                    LANG = "en_US.UTF-8";
                    LC_CTYPE = "en_US.UTF-8";
                };

                window = {
                    opacity = 1; # Specified in floating number from 0.0 to 1.0
                        title = "terminal";
                };
                cursor ={
                    style="Block";
                };

                font = {

                    normal = {
                        family ="Monofur Nerd Font Mono"; 
                        style = "Regular";
                    };
                    size = 15.0;
                };

                selection = {
                    save_to_clipboard = true;
                };
                live_config_reload =true;
                # colors = {
                #     primary = {
                #         background = "#32302f"; # soft contrast
                #             foreground = "#ebdbb2";
                #     };
                #
                #     normal = {
                #         black = "#282828";
                #         red = "#cc241d";
                #         green = "#98971a";
                #         yellow = "#d79921";
                #         blue = "#458588";
                #         magenta = "#b16286";
                #         cyan = "#689d6a";
                #         white = "#a89984";
                #     };
                #
                #     bright = {
                #         black = "#928374";
                #         red = "#fb4934";
                #         green = "#b8bb26";
                #         yellow = "#fabd2f";
                #         blue = "#83a598";
                #         magenta = "#d3869b";
                #         cyan = "#8ec07c";
                #         white = "#ebdbb2";
                #     };
                # };
            };
        };
    };
}
