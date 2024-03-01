{config, pkgs, ...}: 
{
    options = {};
    config = {
        programs.git = {
        enable = true;
        extraConfig = {
            mergetool.nvimdiff.cmd = "nix develop github:ezekielenns/editor --command nvim -d -c \"wincmd l\" -c \"norm ]c\" \"$LOCAL\" \"$MERGED\" \"$REMOTE\"";
            difftool.nvimdiff.cmd = "nix develop github:ezekielenns/editor --command nvim -d  \"$LOCAL\" \"$REMOTE\"";
        };
        };
    };
}
