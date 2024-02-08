#TODO make this more of a home.nix setup?
{config, pkgs, ...}: 
{
    imports = [ ];
    options = {};
    config = let 
      work = pkgs.writeTextFile {
          name = "work.conf";
          text = '' 
            enabled_layouts fat:bias=80;full_size=1;mirrored=false,tall:bias=60;full_size=1;mirrored=false
            launch nix develop github:EzekielEnns/editor --command nvim 
            launch 
          '';
      };
      #finder = ;
      men_bluetooth = pkgs.writeShellApplication {
        name = "men_bluetooth";
        runtimeInputs = [ pkgs.dmenu pkgs.bluez ];
        text = ./../scripts/bluetooth.sh;
      };
      men_power = pkgs.writeTextFile {
        name = "men_power";
        destination = "/bin/men_power";
        executable = true;
        text = ./../scripts/powermenu.sh;
      };
    in{
     #note merges auto matically on deploument
     environment.systemPackages = [
        men_power
        men_bluetooth
        (pkgs.writeShellApplication {
        name = "finder";
        runtimeInputs = [ pkgs.fzf ];
        text = '' 
                set -x
                wp=$(find ~/Documents/repos/* -maxdepth 0 -type d -printf "%f\n" | fzf --prompt="Select a repo: ") || exit
                (cd ~/Documents/repos/"$wp" ; NIXPKGS_ALLOW_UNFREE=1 \
                    nix develop git+ssh://git@github.com/ezekielenns/devenvs#"$wp" --impure \
                    --command bash -c 'kitty --detach --session "${work}"' )

        '';
      })
     ];
    };
    #TODO import i3 config 
}
