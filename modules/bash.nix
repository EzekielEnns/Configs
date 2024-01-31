{config, pkgs, ...}: 
{
    options = {};
    config = {
        # programs.bash = {
        #     enable = true;
        #     enableCompletion = true;
        #     enableLsColors = true;
        #     #bashrcExtra = 
        # };
        environment.etc.bashrc.text = builtins.readFile(../home/.bashrc);
        environment.etc.inputrc.text = builtins.readFile(../home/.inputrc);
    };
    #TODO import i3 config 
}
