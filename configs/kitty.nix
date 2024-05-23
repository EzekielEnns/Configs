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
                "enable_audio_bell"="no";
                "tab_bar_style"="hidden";
            };
            keybindings = {
                "ctrl+shift+equal"="change_font_size all +2.0";
                "cmd+minus"="change_font_size all -2.0 ";
                "ctrl+shift+v"="paste_from_clipboard";
                "ctrl+b>c"="new_tab_with_cwd";
                "ctrl+b>%"="new_window";
                "ctrl+b>w"="select_tab";
                "ctrl+b>"="next_layout";
                "ctrl+b>s"="swap_with_window";
                "ctrl+b>r"="set_tab_title";
                "ctrl+b>space"="focus_visible_window";
                "ctrl+b>n"="start_resizing_window";
                "ctrl+tab"="next_tab";
                "ctrl+shift+tab"="previous_tab";
                "alt+tab"="next_window";
                "alt+shift+tab"="previous_window";
            };
        };
    };
}
