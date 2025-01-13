{config, pkgs, ...}: 
{
    imports = [ ];
    options = {};
    config = let 
    #todo make zsh
      repo_helper = pkgs.writeTextFile {
        name = "repo_helper";
        destination = "/bin/repo_helper";
        executable = true;
        text = ../misc/repo_helper.sh;
      };
    in{
     environment.systemPackages = [
        repo_helper
        (pkgs.writeShellApplication {
        name = "finder";
        runtimeInputs = [ pkgs.fzf ];
        text = '' 
                #! /bin/bash
                set -x
                echo "$SHELL"
                wp=$(find ~/Documents/repos/* -maxdepth 0 -type d -printf "%f\n" | fzf --prompt="Select a repo: ") || exit
                (cd ~/Documents/repos/"$wp" ; NIXPKGS_ALLOW_UNFREE=1 \
                    nix develop --command bash -c "tmux new -As $wp nvim" || tmux new -As "$wp" nvim )

        '';
      })
     ];
    };
    #TODO import i3 config 
}
