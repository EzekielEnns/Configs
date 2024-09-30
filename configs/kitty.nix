{pkgs,...}:
{
    imports = [];
    options = {};
    config = {
        programs.kitty = {
            enable = true;
            font = {
                package = (pkgs.nerdfonts.override { fonts = [ "Monofur" ]; });
                name = "Monofur Nerd Font";
                size = 15;
            };
            settings = {
                "enabled_layouts"= "*";
                "allow_remote_control"= "yes"; 
                "clear_all_shortcuts"= "yes";
                "show_hyperlink_targets"="yes";
                "copy_on_select"="clipboard";
                "tab_bar_style"="hidden";
                "window_alert_on_bell" = "yes";
                "enable_audio_bell" =  "no";
            };
            keybindings = {
                "ctrl+shift+equal"="change_font_size all +2.0";
                "ctrl+shift+minus"="change_font_size all -2.0";
                "cmd+minus"="change_font_size all -2.0 ";
                "ctrl+shift+v"="paste_from_clipboard";
            };
        };
    };
}
