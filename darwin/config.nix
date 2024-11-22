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
            slack
            zoom-us
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
# "${pkgs.slack}/Applications/"
# "/Applications/Firefox.app"
# "${pkgs.obsidian}/Applications/Obsidian.app"
# "/System/Applications/Mail.app"
# "/System/Applications/Calendar.app"
        ];
        finder.FXPreferredViewStyle = "clmv";
        finder.FXEnableExtensionChangeWarning=false;
        finder.CreateDesktop = false;
        loginwindow.GuestEnabled  = false;
        NSGlobalDomain.AppleInterfaceStyle = "Dark";
        NSGlobalDomain.KeyRepeat = 2;
        NSGlobalDomain.AppleSpacesSwitchOnActivate=true;
        NSGlobalDomain.AppleShowAllExtensions = true;
        NSGlobalDomain.AppleShowAllFiles=true;
#https://support.apple.com/en-ca/guide/mac-help/mchlc06d1059/mac
#NSGlobalDomain.AppleKeyboardUIMode=3;
    };
    launchd.agents.alacritty-nvim = {
        enable = true;
        program = "${pkgs.alacritty}/bin/alacritty";
        programArguments = [ "-e" "finder" ];
        runAtLoad = true;
        keepAlive = false;
        workingDirectory = "/Users/ezekielenns";
    };
}
