{pkgs,...}:
{
    imports = [];
    options = {};
    config = {
        programs.starship = {
            enable = true;
            enableBashIntegration = true;
            settings = {
                add_newline = false;
                command_timeout = 10000;
                format ="[>>](bold blue) ";
                success_symbol ="[ >](bold green) ";
                error_symbol ="[x >](bold red) ";
            };
        };

    };
}
