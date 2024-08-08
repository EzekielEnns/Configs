#https://nix-community.github.io/home-manager/index.xhtml#sec-flakes-nixos-module
#https://mipmip.github.io/home-manager-option-search/

#https://git.sr.ht/~sntx/flake/tree/main/item/flake.nix
#https://git.sr.ht/~sntx/flake/tree/main/item/modules/pkgs-usr/sway/default.nix

#TODO make sure im reffrencing user packages
{pkgs,...}:
{
    imports = [];
    options = {};
    config = {
        services.dunst = {
            enable = true;
            settings = {
                global = {
                    #timeout = 0;
                    origin = "top-left";
                };
            };
        };
        # https://nixos.org/manual/nix/stable/language/constructs#with-expressions 
        xsession.windowManager.i3 =  
        let mod="Mod4"; 
            #TODO make sure this is using kitty that is configed 
            term="${pkgs.kitty}/bin/kitty";
            mvw = "move container to workspace ";
        in with pkgs.lib;  {
            enable = true;
            extraConfig = "
# Pulse Audio controls
                bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume 0 +1% #increase sound volume
                bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume 0 -1% #decrease sound volume
                bindsym XF86AudioMute exec --no-startup-id pactl set-sink-mute 0 toggle # mute sound

# Sreen brightness controls
                bindsym XF86MonBrightnessUp exec xbacklight -inc 20 # increase screen brightness
                bindsym XF86MonBrightnessDown exec xbacklight -dec 20 # decrease screen brightness
# Mic
                bindsym XF86AudioMicMute exec --no-startup-id pactl set-source-mute 1 toggle

# Media player controls
                bindsym XF86AudioPlay exec playerctl play-pause
                bindsym XF86AudioPause exec playerctl play-pause
                bindsym XF86AudioNext exec playerctl next
                bindsym XF86AudioPrev exec playerctl previous
                ";
            config = with pkgs;{
                defaultWorkspace = "workspace Editor";
                window = {
                    commands = [
                        {
                            command = "floating enable";
                            criteria = {
                                class="zoom";
                            };
                        }
                        {
                            command = "floating enable, move absolute position center,resize set 640 480"; 
                            criteria = {
                                class="float_term";
                            };
                        }
                        {
                            command = "sticky enable"; 
                            criteria = {
                                floating=true;
                            };
                        }
                        {
                            command = "floating enable"; 
                            criteria = {
                                title="feh";
                            };
                        }
                    ];
                    titlebar = false;
                    border=1;
                    hideEdgeBorders = "smart";
                };
                focus.followMouse = false;
                floating.border = 0;
                fonts = {
                    names = ["pango:Monofur Nerd Font"];
                    size = 0.0;
                };
                startup = [
                    {
                        command = "--no-startup-id ${autorandr}/bin/autorandr -c main 2>/dev/null";
                        always = true;
                        notification = false;
                    }
                    {
                        command = "${unclutter}/bin/unclutter -idle 1";
                        always = true;
                        notification = false;
                    }
                    {
                        command = "--no-startup-id ${xss-lock}/bin/xss-lock --transfer-sleep-lock -- ${i3lock}/bin/i3lock --nofork";
                    }
                    {
                        command = "--no-startup-id ${networkmanagerapplet}/bin/nm-applet";
                    }
                    {
                        command = "--no-startup-id ${feh}/bin/feh --bg-center --randomize ~/Documents/bkgs/*";
                    }
                    {
                        command = "${kitty}/bin/kitty finder";
                    }
                ];
                modifier = mod;
                bars = [
                    {
                      position = "top";
                      statusCommand = "${i3status-rust}/bin/i3status-rs ~/.config/i3status-rust/config-top.toml";
                      fonts = {
                        names = ["pango:Monofur Nerd Font"];
                        size = 10.0;
                        #style = "regulare";
                      };
                      colors = {
                        separator= "#666666";
                        background= "#000000";
                        statusline= "#dddddd";
                        focusedWorkspace = {background= "#0088CC"; border= "#0088CC"; text="#ffffff";};
                        activeWorkspace= {background= "#333333"; border= "#333333"; text="#ffffff";};
                        inactiveWorkspace= {background= "#333333"; border= "#333333"; text="#888888";};
                        urgentWorkspace= {background= "#2f343a"; border= "#900000"; text="#ffffff";};
                      };
                    }
                ];
                 modes = {
                     resize = {
                        "j"=" resize shrink height 10 px or 10 ppt";
                        "k"= "resize grow height 10 px or 10 ppt";
                        "h"= "resize shrink width 10 px or 10 ppt";
                        "l"= "resize grow width 10 px or 10 ppt";
                        "semicolon"="resize grow width 10 px or 10 ppt";
                        "Return" = "mode default";
                        "Escape"= "mode default";
                        "${mod}+o" ="mode default";
                     };
                     move = {
                            "$mod+Tab"="focus right";
                            "h"="move left";
                            "j"="move down";
                            "k"="move up";
                            "l"="move right";

                            "Return"="mode default";
                            "Escape"="mode default";
                     };
                 };
                keybindings = {
                   "${mod}+Return" = "exec ${kitty}/bin/kitty";
                   "${mod}+Shift+Return" = "exec ${kitty}/bin/kitty --class=float_term -e finder";
                   "${mod}+Ctrl+v" = "exec ${maim}/bin/maim -s | ${xclip}/bin/xclip -selection clipboard -t image/png";
                   "${mod}+Shift+v" = "exec ${maim}/bin/maim -s --format=png /dev/stdout | feh -";
                   "${mod}+Ctrl+f" = "exec --no-startup-id ${find-cursor}/bin/find-cursor --color fuchsia --repeat 3";
                   "${mod}+a" = "exec --no-startup-id i3-dmenu-desktop";
                   "${mod}+Ctrl+p" = "exec --no-startup-id men_power"; #TODO check
                   "${mod}+Ctrl+b" = "exec --no-startup-id men_bluetooth";

                   "${mod}+q" = "workspace Editor";
                   "${mod}+Shift+q" = "move container to workspace Editor";
                   "${mod}+e" = "workspace Dev";
                   "${mod}+Shift+e" = mvw+"Dev";
                    #TODO some how make these checks better
                    #TODO add ytermusic
                   "${mod}+m" = "workspace Music; exec [ $( i3-msg -t get_tree | grep \"YouTube Music\" | wc -L) = 0 ] &&  youtube-music ";
                   "${mod}+Shift+m" = mvw+"Music";
                    #TODO add a media worksapce
                   "${mod}+w" = "workspace Web"; #; exec [ $(i3-msg -t get_tree | grep \\\".title.:.Mozilla Firefox.\\\" | wc -L) = 0 ] && firefox 
                   "${mod}+Shift+w" = mvw+"Web";
                   "${mod}+r" = "workspace Comm";
                   "${mod}+Shift+r" = mvw+"Comm";
                   "${mod}+u" = "workspace Utils";
                   "${mod}+Shift+u" = mvw+"Utils";
                   "${mod}+o" = "mode resize";
                   "${mod}+d" = "kill";
                   "${mod}+h" = "focus left";
                   "${mod}+j" = "focus down";
                   "${mod}+k" = "focus up";
                   "${mod}+l" = "focus right";
                    
                   "${mod}+Shift+h" = "move left";
                   "${mod}+Shift+j" = "move down";
                   "${mod}+Shift+k" = "move up";
                   "${mod}+Shift+l" = "move right";

                   "${mod}+t" = "layout toggle tabbed split";
                   "${mod}+f" = "fullscreen toggle";
                   "${mod}+Shift+space" = "floating toggle";

                   "${mod}+Ctrl+c" = "reload";
                   "${mod}+Ctrl+r" = "restart";
                   "${mod}+v" = "split horizontal";
                   "${mod}+s" = "split vertical";
                };
            };
        };
    };
}
