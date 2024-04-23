{config, pkgs, ...}: 
{
    options = {};
    config = {
        programs.git = {
        enable = true;
        extraConfig = {
            mergetool.nvimdiff.cmd = "nvim -d -c \"wincmd l\" -c \"norm ]c\" \"$LOCAL\" \"$MERGED\" \"$REMOTE\"";
            difftool.nvimdiff.cmd = "nvim -d  \"$LOCAL\" \"$REMOTE\"";
            push.default = "current";
        };
        };
    };
}
