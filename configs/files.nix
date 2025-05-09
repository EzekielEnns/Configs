{config,...}: 
{
    config = {
        home.file.".ideavimrc" = {source =./../misc/.ideavimrc; recursive=true;force=true;};
        #prevent issue on linux
        home.file.".zshrc" = {force=true; text=""; };
        home.file.".config/ghostty/config" = {
            force =true;
            text = ''
            keybind = alt+left=unbind
            keybind = alt+right=unbind
            macos-option-as-alt = true
            macos-titlebar-style = "native"
            macos-titlebar-proxy-icon = hidden
            keybind = ctrl+a>n=new_window
            keybind = ctrl+a>h=toggle_window_decorations
            font-size = 15
            font-family = "Monofur Nerd Font Mono"
            theme = gruvbox-material
            quit-after-last-window-closed = true
            cursor-style = block
            cursor-style-blink = false
            shell-integration-features = no-cursor
            mouse-hide-while-typing = true
            window-subtitle = false
            title = " "
            clipboard-write = allow
            copy-on-select = true
            '';
        };

        home.file.".config/zellij/config.kdl" = {
            text = (builtins.readFile ./../misc/config.kdl)+''
                layout_dir "${config.home.homeDirectory}/.config/zellij/layouts"
            ''; 
            force =true;
        };
        home.file.".config/zellij/layouts/.keep" = {
            text = "keep"; 
        };
    };
}
