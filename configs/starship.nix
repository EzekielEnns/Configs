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
                format ="$all$line_break[>>](bold blue) ";
                character = {
                    success_symbol ="";
                    error_symbol = "[x](bold red) ";
                };
            };
        };

    };
}
