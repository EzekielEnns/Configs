{pkgs,lib,...}:
{
    imports = [];
    options = {};
    config = {
       programs.kitty.font.size = lib.mkForce 11;
    };
}
