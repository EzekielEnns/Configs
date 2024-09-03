#TODO make this more of a home.nix setup?
{config, pkgs, ...}: 
{
    imports = [ ];
    options = {};
    config = let 
      men_bluetooth = pkgs.writeShellApplication {
        name = "men_bluetooth";
        runtimeInputs = [ pkgs.dmenu pkgs.bluez ];
        text = ../misc/bluetooth.sh;
      };
      men_power = pkgs.writeTextFile {
        name = "men_power";
        destination = "/bin/men_power";
        executable = true;
        text = ../misc/powermenu.sh;
      };
      repo_helper = pkgs.writeTextFile {
        name = "repo_helper";
        destination = "/bin/repo_helper";
        executable = true;
        text = ../misc/repo_helper.sh;
      };
    in{
     environment.systemPackages = [
        men_power
        men_bluetooth
        repo_helper
        (pkgs.writeShellApplication {
        name = "finder";
        runtimeInputs = [ pkgs.fzf ];
        text = '' 
                set -x
                wp=$(find ~/Documents/repos/* -maxdepth 0 -type d -printf "%f\n" | fzf --prompt="Select a repo: ") || exit
                (cd ~/Documents/repos/"$wp" ; NIXPKGS_ALLOW_UNFREE=1 \
                    nix develop --command bash -c "tmux new -As $wp nvim" || tmux new -As $wp nvim )

        '';
      })
     ];
    };
    #TODO import i3 config 
}
