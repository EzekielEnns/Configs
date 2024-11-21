{config, pkgs, ...}: 
{
    options = {};
    config = {
        services.yabai = {
            enable = true;
            config = {
                auto_balance = "on";
                layout = "i3";
                bottom_padding = 48;
                left_padding = 18;
                right_padding = 18;
                top_padding = 18;
                window_gap = 18;
                mouse_follows_focus = "on";
                mouse_modifier = "fn";
                split_ratio = "0.50";
                window_border = "off";
                window_placement = "second_child";
                window_topmost = "on";
            };
            extraConfig = ''
# rules
                yabai -m rule --add app='System Preferences' manage=off
                '';
        };
        services.skhd = {
            enable = true;
            package = pkgs.skhd;
            skhdConfig = ''
# Focus window
                ctrl + alt - h : yabai -m window --focus west
                ctrl + alt - j : yabai -m window --focus south
                ctrl + alt - k : yabai -m window --focus north
                ctrl + alt - l : yabai -m window --focus east

# Fill space with window
                ctrl + alt - 0 : yabai -m window --grid 1:1:0:0:1:1

# Move window
                ctrl + alt - e : yabai -m window --display 1; yabai -m display --focus 1
                ctrl + alt - d : yabai -m window --display 2; yabai -m display --focus 2
                ctrl + alt - f : yabai -m window --space next; yabai -m space --focus next
                ctrl + alt - s : yabai -m window --space prev; yabai -m space --focus prev

# Close current window
                ctrl + alt - d : $(yabai -m window $(yabai -m query --windows --window | jq -re ".id") --close)

# Rotate tree
                ctrl + alt - r : yabai -m space --rotate 90

# Open application
                ctrl + alt - enter : kitty
                # ctrl + alt - e : emacs
                # ctrl + alt - b : open -a Safari
                #
                # ctrl + alt - t : yabai -m window --toggle float;\
                # yabai -m window --grid 4:4:1:1:2:2
                #
                # ctrl + alt - p : yabai -m window --toggle sticky;\
                # yabai -m window --toggle topmost;\
                # yabai -m window --toggle pip
                '';
        };
    };
}
