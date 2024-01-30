#https://nix-community.github.io/home-manager/index.xhtml#sec-flakes-nixos-module
#https://mipmip.github.io/home-manager-option-search/

#https://git.sr.ht/~sntx/flake/tree/main/item/flake.nix
#https://git.sr.ht/~sntx/flake/tree/main/item/modules/pkgs-usr/sway/default.nix

#TODO make sure im reffrencing user packages
{config, pkgs,...}:
{
    # https://nixos.org/manual/nix/stable/language/constructs#with-expressions 
    xsession.windowManager.i3 =  
    let mod="Mod4"; 
        #TODO make sure this is using kitty that is configed 
        term="${pkgs.kitty}/bin/kitty";
    in with pkgs.lib; {
        enable = true;
        modifier= mod;
        config = {
            keybindings = lib.mkOptionDefault {
                #TODO add more
               "${mod}+enter" = "exec ${term}";
            };
        };
    };
}
