{config, pkgs, ...}: 
{
    options = {};
    config = {
        programs.git = {
        userName  = "Zeke";
        userEmail = "ezekiel.enns@protonmail.com";
        enable = true;
        aliases = {
            capri-sun ="!f() { if [ \"\$1\" = \"-a\" ]; then git commit -am \"\$(git rev-parse --abbrev-ref HEAD) \$2\"; else git commit -m \"\$(git rev-parse --abbrev-ref HEAD) \$1\"; fi; }; f";
        };
        extraConfig = {
            mergetool.nvimdiff.cmd = "nvim -d -c \"wincmd l\" -c \"norm ]c\" \"$LOCAL\" \"$MERGED\" \"$REMOTE\"";
            difftool.nvimdiff.cmd = "nvim -d  \"$LOCAL\" \"$REMOTE\"";
            push.default = "current";
        };
        };
    };
}
