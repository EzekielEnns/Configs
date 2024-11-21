#TODO make bash
{config, pkgs, ...}: 
{
    options = {};
    config = {

        environment.systemPackages = with pkgs; [
            fzf
            neofetch 
            mpv
        ];
        environment.variables = {
            EDITOR = "nvim";
            FZF_COMPLETION_TRIGGER="**";
            FZF_COMPLETION_OPTS="--border --info=inline";
            VISUAL = "nvim";
            NIXPKGS_ALLOW_UNFREE = "1";
        };
        programs.zsh = {
            enableFzfCompletion = true;
            enableFzfHistory = true;
            enableFzfGit = true;
            enableFastSyntaxHighlighting= true;
            enableSyntaxHighlighting=true;
            initExtra = ''
                eval "$(starship init zsh)"
                eval "$(direnv hook zsh)"
                '';
        };
        programs.direnv = {
            enable = true;
            nix-direnv.enable = true;
        };
        programs.bash = { 
            shellAliases = {
                cls = "clear";
            };
        };
    };
}
