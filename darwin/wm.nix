{config, pkgs, ...}: 
{
    options = {};
    config = {
        services.yabai = {
            enable = true;
            config = {
                auto_balance = "on";
                layout = "bsp";
            };
            extraConfig = ''
# rules

                yabai -m rule --add app='System Preferences' manage=off
                '';
        };
#dose not work?
        services.skhd = {
            enable = true;
            package = pkgs.skhd;
            skhdConfig = ''
# Focus window
                alt - h : yabai -m window --focus west
                alt - j : yabai -m window --focus south
                alt - k : yabai -m window --focus north
                alt - l : yabai -m window --focus east

# # Fill space with window
#                 cmd + alt - 0 : yabai -m window --grid 1:1:0:0:1:1
#
# # Move window
#                 cmd + alt - e : yabai -m window --display 1; yabai -m display --focus 1
#                 cmd + alt - d : yabai -m window --display 2; yabai -m display --focus 2
#                 cmd + alt - f : yabai -m window --space next; yabai -m space --focus next
#                 cmd + alt - s : yabai -m window --space prev; yabai -m space --focus prev

# Close current window
                # cmd + alt - d : $(yabai -m window $(yabai -m query --windows --window | jq -re ".id") --close)

# Rotate tree
                # cmd + alt - r : yabai -m space --rotate 90
# Open application
                # shift + cmd - return : alacritty 
                # cmd + alt - e : emacs
                # cmd + alt - b : open -a Safari
                #
                # cmd + alt - t : yabai -m window --toggle float;\
                # yabai -m window --grid 4:4:1:1:2:2
                #
                # cmd + alt - p : yabai -m window --toggle sticky;\
                # yabai -m window --toggle topmost;\
                # yabai -m window --toggle pip
                '';
        };
    };
}
