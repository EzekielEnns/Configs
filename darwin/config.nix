{ config, pkgs, ... }:

{
    imports = [
        ../modules/nvim.nix
            ./zsh.nix
            ./scripts.nix
    ];

    services.nix-daemon.enable = true;
    nixpkgs.config.allowUnfree = true;
    nix.package = pkgs.nix;
    nix.settings.experimental-features = "nix-command flakes";
    system.defaults.dock.autohide-delay = 0.0;
    environment.systemPackages = with pkgs; [
        mkalias
            alacritty
    ];
    users.users.ezekielenns = {
        name = "ezekielenns";
        home = "/Users/ezekielenns";
    };
    fonts = {
        packages = with pkgs; [
            noto-fonts
                font-awesome
                source-han-sans
                source-han-sans-japanese
                source-han-serif-japanese
                (nerdfonts.override { fonts = [ "Monofur" ]; })
        ];
    };
#getting apps into spotlight
    system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
            name = "system-applications";
            paths = config.environment.systemPackages;
            pathsToLink = "/Applications";
        };
    in
        pkgs.lib.mkForce ''
        # Set up applications.
        echo "setting up /Applications..." >&2
        rm -rf /Applications/Nix\ Apps
        mkdir -p /Applications/Nix\ Apps
        find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
        while read -r src; do
            app_name=$(basename "$src")
                echo "copying $src" >&2
                ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
                done
                '';
}
