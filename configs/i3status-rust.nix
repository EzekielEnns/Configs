{config,pkgs,...}:
{
    imports = [];
    options = {};
    config = {

        programs.waybar = {
            enable = true;
            settings = 
{
  mainBar = {
    layer = "top";
    position = "top";
    height = 30;
    output = [
      "eDP-1"
      "HDMI-A-1"
    ];
    modules-left = [ "sway/workspaces" "sway/mode" "wlr/taskbar" ];
    modules-center = [ "sway/window" "custom/hello-from-waybar" ];
    modules-right = [ "mpd" "battery" "tray" ];

    "sway/workspaces" = {
      disable-scroll = true;
      all-outputs = true;
    };
    "custom/hello-from-waybar" = {
      format = "hello {}";
      max-length = 40;
      interval = "once";
      exec = pkgs.writeShellScript "hello-from-waybar" ''
        echo "from within waybar"
      '';
    };
  };
};
        };
        programs.i3status-rust= {
            enable = true;
            bars = {
                top = {
                    icons = "awesome5";
                    theme = "plain";
                    blocks = [
                        {
                            block = "disk_space";
                            path = "/";
                            info_type = "used";
                            format = " $used";
                        }
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
                            block = "battery";
                            format = " $icon   $percentage ";
                        }
                        { block = "backlight"; }
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
                            timezone = "Canada/Atlantic";
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
