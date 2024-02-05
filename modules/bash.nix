{config, pkgs, ...}: 
{
    options = {};
    config = {
        environment.etc.bashrc.text = builtins.readFile(../home/.bashrc);
        environment.etc.inputrc.text = builtins.readFile(../home/.inputrc);
        programs.bash.shellAliases = {
            #this keeps my editor always up-todate so i dont need to update
            #my whole os everytime i change my editor
            nvim = "nix develop github:ezekielenns/editor --command nvim";
        };
    };
}
