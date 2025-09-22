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
