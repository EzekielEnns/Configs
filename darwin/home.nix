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
        home.file.".yabairc".text = ''
            yabai -m config layout bsp
            yabai -m config auto_balance on
            yabai -m config mouse_follows_focus on
            yabai -m rule --add app='System Preferences' manage=off
            yabai -m config mouse_modifier fn
            yabai -m config mouse_action1 move
            yabai -m config mouse_action2 resize
        '';
        # home.file.".skhdrc".text = ''
        #         alt - h : yabai -m window --focus west
        #         alt - j : yabai -m window --focus south
        #         alt - k : yabai -m window --focus north
        #         alt - l : yabai -m window --focus east
        #         alt - < : yabai -m display --focus 1
        #         alt - > : yabai -m display --focus 2
        #         alt - n : yabai -m space --focus next
        #         alt - p : yabai -m space --focus prev
        # '';
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
                    opacity = 1.0; # Specified in floating number from 0.0 to 1.0
                    title = "terminal";
                    decorations="none";
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
                # general = {
                #     live_config_reload =true;
                # };
            };
        };
    };
}
