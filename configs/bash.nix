{config, pkgs, ...}: 
{
    options = {};
    config = {
        environment.etc.bashrc.text = builtins.readFile(../misc/.bashrc);
        environment.etc.inputrc.text = builtins.readFile(../misc/.inputrc);
        programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
        };
        programs.bash = { 
            shellAliases = {
                yt-dl-audio = "yt-dlp --ignore-errors --output '%(title)s.%(ext)s' --extract-audio --audio-format wav";
                cls = "clear";
            };
        };
    };
}
