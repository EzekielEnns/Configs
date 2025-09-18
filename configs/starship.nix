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
                format ="$all[$time]($style) $cmd_duration$line_break[>>](bold blue) ";
                time = {
                    disabled = false;
                    time_format = "%Y-%m-%d %H:%M:%S"; 
                    format = "$time";                
                    style = "bold dimmed";
                };

                cmd_duration = {
                    min_time = 0;                      
                    format = "took [$duration]($style)";
                    show_milliseconds = true;
                    style = "italic";
                };
                character = {
                    success_symbol ="";
                    error_symbol = "[x](bold red) ";
                };
            };
        };

    };
}
