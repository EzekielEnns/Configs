{config,pkgs,...}:
{
    imports = [];
    options = {};
    config = {
        programs.i3status-rust= {
            enable = true;
            bars = {
                top = {
                    icons = "awesome5";
                    theme = "plain";
                    blocks = [
                        {
                            block = "xrandr";
                            icons_format = "{icon}";
                            format = "$display";
                        }
                        {
                            block = "disk_space";
                            path = "/";
                            info_type = "used";
                            format = " $used";
                        }
                        # {
                        #     block = "load";
                        #     interval = 5;
                        #     icons_format = "{icon} ";
                        # }
                        {
                            block = "memory";
                            format = " $icon  $mem_used_percents ";
                            format_alt = " $icon_swap $swap_used_percents ";
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
                            block = "music";
                            format = " $icon {$combo.str(max_w:20,rot_interval:0.5) $play $next |}";
                        }
                        {
                            block = "sound";
                            step_width = 3;
                            format = " $icon  $volume|";
                        }
                        {
                            block = "time";
                            interval = 1;
                            format=" $icon  $timestamp.datetime(f:'%x    %I:%M', l:fr_BE)  ";
                            timezone = "Canada/Mountain";
                        }
                        {
                            format = " $text ";
                            block = "uptime";
                            interval = 1;
                        }
                    ];
                };
            };
        };
    };
}
