{...}: 
{
    config = {
        home.file.".ideavimrc" = {source =./../misc/.ideavimrc; recursive=true;};
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
    };
}
