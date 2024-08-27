{config,pkgs,...}:
{
    imports = [];
    options = {};
    config = {
        programs.waybar = {
            enable = true;
            systemd.enable = true;
            systemd.target = "sway-session.target";
            settings = 
            {
                mainBar = {
                    layer = "top";
                    position = "top";
                    height = 24;
                    output = [
                        #"eDP-1"
                        "*"
                    ];
                    modules-left = [ "hyprland/workspaces"  ];
                    modules-center = [ "clock" "date" ];
                    modules-right = ["pulseaudio" "temperature" "disk" "cpu" "memory" "battery" "tray"];

                    "hyprland/workspaces" = {
                        disable-scroll = true;
                        all-outputs = true;
                    };

                    tray= {
                        spacing= 10;
                    };
                    clock= {
                        format= "{:%I:%M %p :: %Y-%m-%d}";
                    };
                    cpu= {
                        format= "{usage}  ";
                        };
                    memory= {
                        format= "{}  ";
                        };
                    battery= {
                        bat= "BAT0";
                        states= {
                            warning= 30;
                            critical= 15;
                        };
                        format= "{capacity} {icon}";
                        format-icons= ["" "" "" "" ""];
                    };
                    network= {
                        format-wifi= "{essid} ({signalStrength}%) ";
                        format-ethernet= "{ifname}: {ipaddr}/{cidr} ";
                        format-disconnected= "Disconnected ⚠";
                    };
                    pulseaudio= {
                        format= "{volume} {icon} ";
                        format-bluetooth= "{volume} {icon} ";
                        format-muted= "";
                        format-icons= {
                            default= ["" ""];
                        };
                        on-click= "pavucontrol";
                    };
                    disk = {
                        interval= 30;
                        format= "{specific_free:0.0f}/{specific_total:0.0f} GB 💿";
                        unit = "GB";
                    };
                };
            };

            style = ''
                * {
                    border: none;
                    border-radius: 0;
                    font-family: "Ubuntu Nerd Font";
                    font-size: 13px;
                    min-height: 0;
                    background: transparent;
                    color: white;
                }

                window#waybar {
                    background: transparent;
                }

                #window {
                    font-weight: bold;
                    font-family: "Ubuntu";
                }

                #workspaces button {
                    padding: 0 5px;
                    background: transparent;
                    color: white;
                    border-top: 2px solid transparent;
                }

                #workspaces button.focused {
                    color: #c9545d;
                    border-top: 2px solid #c9545d;
                }

                #mode {
                    background: #64727D;
                    border-bottom: 3px solid white;
                }

                #clock, #battery, #cpu, #memory, #network, #pulseaudio, #custom-spotify, #tray, #mode {
                    padding: 0 3px;
                    margin: 0 2px;
                }

                #clock {
                    font-weight: bold;
                }

                #battery {
                }

                #battery icon {
                    color: red;
                }

                #battery.charging {
                }

                @keyframes blink {
                    to {
                        background-color: #ffffff;
                        color: black;
                    }
                }

                #battery.warning:not(.charging) {
                    color: white;
                    animation-name: blink;
                    animation-duration: 0.5s;
                    animation-timing-function: linear;
                    animation-iteration-count: infinite;
                    animation-direction: alternate;
                }

                #cpu {
                }

                #memory {
                }

                #network {
                }

                #network.disconnected {
                    background: #f53c3c;
                }

                #pulseaudio {
                }

                #pulseaudio.muted {
                }

                #custom-spotify {
                    color: rgb(102, 220, 105);
                }

                #tray {
                }
            '';
        };
    };
}
