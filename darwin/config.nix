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
    environment.systemPackages = with pkgs; [
        mkalias
        fontconfig
        findutils
    ];
    users.users.ezekielenns = {
        name = "ezekielenns";
        home = "/Users/ezekielenns";
    };
    fonts.packages = [
        (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" "Monofur" ]; })
    ];
    system.defaults = {
        dock.autohide  = true;
        dock.persistent-apps = [
            "${pkgs.alacritty}/Applications/Alacritty.app"
# "/Applications/Firefox.app"
# "${pkgs.obsidian}/Applications/Obsidian.app"
# "/System/Applications/Mail.app"
# "/System/Applications/Calendar.app"
        ];
        finder.FXPreferredViewStyle = "clmv";
        loginwindow.GuestEnabled  = false;
        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.AppleInterfaceStyle = "Dark";
        NSGlobalDomain.KeyRepeat = 2;
    };
}
