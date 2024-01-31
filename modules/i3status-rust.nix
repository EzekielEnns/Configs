{pkgs,...}:
{
    imports = [];
    options = {};
    config = {
        programs.i3status-rust= {
            enable = true;
            bars = {
                top = {
                    icons = "awesome5";
                    blocks = [
                        {
                            block = "xrandr";
                            icons_format = "\u0020{icon} \u0020";
                            format = "$display";
                        }
                        {
                            block = "disk_space";
                            path = "/";
                            info_type = "used";
                            format = " $used";
                        }
                        {
                            block = "load";
                            interval = 5;
                            icons_format = "{icon} \u0020";
                        }
                        {
                            block = "memory";
                            format = " $icon  $mem_used_percents.eng(w:1) ";
                            format_alt = " $icon_swap $swap_free.eng(w:3,u:B,p:M)/$swap_total.eng(w:3,u:B,p:M)($swap_used_percents.eng(w:2)) ";
                            interval = 30;
                            warning_mem = 70;
                            critical_mem = 90;
                        }
                        {
                            block = "temperature";
                            format = " $icon $max max ";
                            format_alt = " $icon $min min, $max max, $average avg ";
                            interval = 10;
                            chip = "*-pci-*";
                        }
                        {
                            block = "battery";
                            format = " $icon  $percentage ";
                        }
                        { block = "backlight"; }
                        {
                            block = "sound";
                            step_width = 3;
                            format = " $icon  $volume|";
                        }
                        {
                            block = "music";
                            format = " $icon {$combo.str(max_w:20,rot_interval:0.5) $play $next |}";
                            interface_name_exclude = [".*kdeconnect.*" "mpd"];
                        }
                        {
                            block = "time";
                            interval = 1;
                            format=" $icon  $timestamp.datetime(f:'%x %I:%M', l:fr_BE)  ";
                            timezone = "Canada/Atlantic";
                        }
                        {
                            format = " $text ";
                            block = "uptime";
                            interval = 3600 ;
                        }
                    ];
                };
            };
        };
    };
}
