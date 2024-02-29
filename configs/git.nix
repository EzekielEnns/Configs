{config, pkgs, ...}: 
{
    options = {};
    config = {
        enable = true;
        extraConfig = {
            mergetool.nvimdiff.cmd = "nix develop github:ezekielenns/editor --command nvim -d -c \"wincmd l\" -c \"norm ]c\" \"$LOCAL\" \"$MERGED\" \"$REMOTE\"";
        };
    };
}
