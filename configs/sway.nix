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
        services.mako = {
            enable = true;
                anchor =  "top-left";
        };
wayland.windowManager.hyprland = with pkgs; {
    enable = true;
    extraConfig = ''
# General Settings
        monitor=,preferred,auto, 1
        exec-once = ${waybar}/bin/waybar
        decoration:blur:enabled = false
        decoration:drop_shadow = false
        misc:vfr = true
        dwindle:permanent_direction_override = true
        dwindle:preserve_split = true
# Keybindings
        bind=SUPER, Return, exec, ${kitty}/bin/kitty
        bind=SUPER SHIFT, Return, exec, ${kitty}/bin/kitty --class=float_term -e finder
        bind=SUPER CTRL, v,exec, ${grim}/bin/sh -g \"$(slurp - d)\" - | wl-copy --type image/png
        bind=SUPER SHIFT, v, exec, grim -g \"$(slurp)\" - | swayimg - "
        bind=SUPER CTRL, f,exec,find-cursor --color fuchsia --repeat 3
        bind=SUPER, a,exec, bemenu-run
        bind=SUPER, d, killactive
        bind=SUPER CTRL, p,exec, men_power 
        bind=SUPER CTRL ,b,exec, men_bluetooth
        bind=SUPER, q,workspace,name:Editor
        bind=SUPER, e,workspace,name:Dev
        bind=SUPER, m,workspace,name:Music,exec,[ $(hyprctl clients | grep "YouTube Music" | wc -l) = 0 ] && youtube-music
        bind=SUPER, w,workspace,name:Web
        bind=SUPER, r,workspace,name:Comm
        bind=SUPER SHIFT, e,movetoworkspacesilent,name:Dev
        bind=SUPER SHIFT, q,movetoworkspacesilent,name:Editor
        bind=SUPER SHIFT, w,movetoworkspacesilent,name:Web
        bind=SUPER SHIFT, m,movetoworkspacesilent,name:Music
        bind=SUPER SHIFT, r,movetoworkspacesilent,name:Comm

# Resize Mode
        # bind=SUPER+o,exec,hyprctl dispatch changelayout resize
        # bind=Resize,h,resize,-10,0
        # bind=Resize,j,resize,0,10
        # bind=Resize,k,resize,0,-10
        # bind=Resize,l,resize,10,0
        # bind=Resize,Return,exec,hyprctl dispatch changelayout default
        # bind=Resize,Escape,exec,hyprctl dispatch changelayout default

# System Controls
        bind= , XF86AudioRaiseVolume,exec,pactl set-sink-volume @DEFAULT_SINK@ +10%
        bind= , XF86AudioLowerVolume,exec,pactl set-sink-volume @DEFAULT_SINK@ -10%
        bind= , XF86AudioMute,exec,pactl set-sink-mute @DEFAULT_SINK@ toggle
        bind= , XF86AudioMicMute,exec,pactl set-source-mute @DEFAULT_SOURCE@ toggle
        bind= , XF86MonBrightnessUp,exec,light -A 5
        bind= , XF86MonBrightnessDown,exec,light -U 5

# Focus and Movement
        bind=SUPER, s, layoutmsg, preselect d
        bind=SUPER, v, layoutmsg, preselect r
        bind=SUPER,h,movefocus, l
        bind=SUPER,j,movefocus, d
        bind=SUPER,k,movefocus, u
        bind=SUPER,l,movefocus, r
        bind=SUPER SHIFT,h,movewindow, l
        bind=SUPER SHIFT,j,movewindow, d
        bind=SUPER SHIFT,k,movewindow, u
        bind=SUPER SHIFT,l,movewindow, r

# Floating Windows
         bind=SUPER SHIFT, space, togglefloating
        # bind=SUPER+space,togglefocusmode

# Fullscreen
        bind=SUPER,f,fullscreen

# Config Reload and Restart
        # bind=SUPER+CTRL ,c,exec,hyprctl reload
        # bind=SUPER+CTRL ,r,exec,hyprctl restart

# Floating Rules
        # rule=class=float_term,move,center,resize,640,480
        # rule=title=feh,move,center,floating,enabled
        # rule=windowrole=toolbox,move,center,floating,enabled

# Autostart Applications
        exec-once=nm-applet
        exec-once=kitty -e finder

# Bar Configuration
# TODO: Hyprland doesn’t have an i3-style bar by default; you might want to use an external bar like Waybar or Polybar for similar functionality.

# Workspace Names
workspace=name:Editor
workspace=name:Dev
workspace=name:Comm
workspace=name:Web
workspace=name:Music
    '';
};
        # https://nixos.org/manual/nix/stable/language/constructs#with-expressions 
        wayland.windowManager.sway =  
        let mod="Mod4"; 
            #TODO make sure this is using kitty that is configed 
            term="${pkgs.kitty}/bin/kitty";
            mvw = "move container to workspace ";
        in with pkgs.lib;  {
            systemd.enable = true;
            enable = true;
            config = with pkgs;{
                defaultWorkspace = "workspace Editor";
                output = {
                    "*" = {
                        bg = "#000000 solid_color";
                    };
                };
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
                            command = "floating enable; sticky enable"; 
                            criteria = {
                                title="feh";
                            };
                        }
                    ];
                    border=2;
                    titlebar = false;
                    hideEdgeBorders = "smart";
                };
                focus.followMouse = false;
                floating.border = 0;
                fonts = {
                    names = ["pango:Monofur Nerd Font"];
                };
                startup = [
                    # {
                    #     command = "${unclutter}/bin/unclutter -idle 1";
                    #     always = true;
                    # }
                    {
                        command = "--no-startup-id ${networkmanagerapplet}/bin/nm-applet";
                    }
                    {
                        command = "${kitty}/bin/kitty finder";
                    }
                ];
                modifier = mod;
                bars = [
                    {command = "${waybar}/bin/waybar";}
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
                            "${mod}+Tab"="focus right";
                            "h"="move left";
                            "j"="move down";
                            "k"="move up";
                            "l"="move right";

                            "Return"="mode default";
                            "Escape"="mode default";
                     };
                 };
                keybindings = {
                   "XF86AudioRaiseVolume" = "exec --no-startup-id pactl set-sink-volume 0 +1% #increase sound volume";
                   "XF86AudioLowerVolume" = "exec --no-startup-id pactl set-sink-volume 0 -1% #decrease sound volume";
                   "XF86AudioMute" = "exec --no-startup-id pactl set-sink-mute 0 toggle # mute sound";
                   "XF86MonBrightnessUp" = "exec xbacklight -inc 20 # increase screen brightness";
                   "XF86MonBrightnessDown" = "exec xbacklight -dec 20 # decrease screen brightness";
                   "XF86AudioMicMute" = "exec --no-startup-id pactl set-source-mute 1 toggle";
                   "XF86AudioPlay" = "exec playerctl play-pause";
                   "XF86AudioPause " = "exec playerctl play-pause";
                   "XF86AudioNext " = "exec playerctl next";
                   "XF86AudioPrev " = "exec playerctl previous";
                   "${mod}+Return" = "exec ${kitty}/bin/kitty";
                   "${mod}+Shift+Return" = "exec ${kitty}/bin/kitty --class=float_term -e finder";
                   "${mod}+Ctrl+v" = "exec ${grim}/bin/sh -g \"$(slurp - d)\" - | wl-copy --type image/png";
                   "${mod}+Shift+v" = " exec grim -g \"$(slurp)\" - | swayimg - ";
                   "${mod}+Ctrl+f" = "exec --no-startup-id ${find-cursor}/bin/find-cursor --color fuchsia --repeat 3";
                   "${mod}+a" = "exec --no-startup-id bemenu-run";
                   "${mod}+Ctrl+p" = "exec --no-startup-id men_power"; #TODO check
                   "${mod}+Ctrl+b" = "exec --no-startup-id men_bluetooth";

                   "${mod}+q" = "workspace Editor";
                   "${mod}+Shift+q" = "move container to workspace Editor";
                   "${mod}+e" = "workspace Dev";
                   "${mod}+Shift+e" = mvw+"Dev";
                    #TODO make work
                   "${mod}+m" = "workspace Music; exec [ $( swaymsg -t get_tree | grep \"YouTube Music\" | wc -L) = 0 ] &&  youtube-music ";
                   "${mod}+Shift+m" = mvw+"Music";
                    #TODO add a media worksapce
                   "${mod}+w" = "workspace Web"; 
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
                   "${mod}+space" = "sticky toggle";

                   "${mod}+Ctrl+c" = "reload";
                   "${mod}+Ctrl+r" = "restart";
                   "${mod}+v" = "split horizontal";
                   "${mod}+s" = "split vertical";
                };
            };
        };
    };
}
