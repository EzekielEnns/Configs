{pkgs,...}:
{
    imports = [];
    options = {};
    config = {
        programs.starship = {
            enable = true;
            enableBashIntegration = true;
            enableZshIntegration = true;
            settings = {
                add_newline = false;
                command_timeout = 10000;
                # Default 30ms is too short for big workspace dirs (e.g. a work checkout with
                # every repo cloned inside it): the scan times out and prints a WARN on exit.
                scan_timeout = 200;
                format ="$all$time$line_break[>>](bold blue) ";
                time = {
                    disabled = false;
                    time_format = "%T"; 
                    format = "[$time]($style)";                
                    style = "italic dimmed white";
                };

                cmd_duration = {
                    min_time = 0;                      
                    format = "[$duration]($style)";
                    show_milliseconds = true;
                    style = "italic dimmed white";
                    #                    style = "italic";
                };
                character = {
                    success_symbol ="";
                    error_symbol = "[x](bold red) ";
                };
            };
        };

    };
}
