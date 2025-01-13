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
        home.file.".config/ghostty/config".text = ''
            font-size = 15
            font-family = "Monofur Nerd Font Mono"
            theme = gruvbox-material

            cursor-style = block
            cursor-style-blink = false
            shell-integration-features = no-cursor

            mouse-hide-while-typing = true
            title = " "
            clipboard-write = allow
            copy-on-select = true
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

        programs.kitty = {
            enable = true;
            package = pkgs.emptyDirectory;
            font = {
                package = (pkgs.nerdfonts.override { fonts = [ "Monofur" ]; });
                name = "Monofur Nerd Font";
                size = 15;
            };
            settings = {
                "macos_hide_titlebar" = "yes";
                "enabled_layouts"= "*";
                "allow_remote_control"= "yes"; 
                "clear_all_shortcuts"= "yes";
                "show_hyperlink_targets"="yes";
                "copy_on_select"="clipboard";
                "tab_bar_style"="hidden";
                "window_alert_on_bell" = "no";
                "enable_audio_bell" =  "no";
                "shell"=".";
            };
            keybindings = {
                "ctrl+shift+equal"="change_font_size all +2.0";
                "ctrl+shift+minus"="change_font_size all -2.0";
                "cmd+minus"="change_font_size all -2.0 ";
                "cmd+v"="paste_from_clipboard";
            };
        };
        # programs.alacritty = {
        #     enable = true;
        #     settings = {
        #         env = {
        #             TERM = "alacritty";
        #             LANG = "en_US.UTF-8";
        #             LC_CTYPE = "en_US.UTF-8";
        #         };
        #
        #         window = {
        #             opacity = 1.0; # Specified in floating number from 0.0 to 1.0
        #             title = "terminal";
        #             decorations="none";
        #         };
        #         cursor ={
        #             style="Block";
        #         };
        #
        #         font = {
        #
        #             normal = {
        #                 family ="Monofur Nerd Font Mono"; 
        #                 style = "Regular";
        #             };
        #             size = 15.0;
        #         };
        #
        #         selection = {
        #             save_to_clipboard = true;
        #         };
        #         # general = {
        #         #     live_config_reload =true;
        #         # };
        #     };
        # };
    };
}
