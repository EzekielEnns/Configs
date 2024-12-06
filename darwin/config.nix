{ config, pkgs,pkgs-unstable, ... }:

{
    imports = [
            ../modules/nvim.nix
            ./zsh.nix
            ./scripts.nix
            ./wm.nix
    ];

    services.nix-daemon.enable = true;
    nixpkgs.config.allowUnfree = true;
    nix.package = pkgs.nix;
    nix.settings.experimental-features = "nix-command flakes";
    environment.systemPackages = with pkgs; [
            pkgs-unstable.youtube-music
            pkgs-unstable.jetbrains.rider
            #needed for bash script
            findutils
            dotnet-sdk_8 
            slack
            zoom-us
    ];
    users.users.ezekielenns = {
        name = "ezekielenns";
        home = "/Users/ezekielenns";
    };
    fonts.packages = [
        (pkgs.nerdfonts.override { fonts = [  "Monofur"  ]; })
    ];

    system.startup.chime=false;
    system.defaults = {
        dock = {
            autohide  = true;
            persistent-apps = [
                "${pkgs.alacritty}/Applications/Alacritty.app"
                "${pkgs.slack}/Applications/Slack.app"
                "${pkgs.youtube-music}/Applications/YouTube\ Music.app"
                "/System/Applications/Mail.app"
                "/System/Applications/Calendar.app"
            ];
            expose-animation-duration = 0.0;
            tilesize=25;
            autohide-time-modifier=0.0;
            static-only = true;
            launchanim = false;
            show-recents = false;
            orientation = "bottom";
            appswitcher-all-displays=true;
        };
        controlcenter= {
            BatteryShowPercentage=true;
        };
        # universalaccess= {
        #     reduceMotion=true;
        #     reduceTransparency=true;
        # };
        finder.QuitMenuItem=true;
        finder.FXPreferredViewStyle = "clmv";
        finder.FXEnableExtensionChangeWarning=false;
        finder.CreateDesktop = false;
        loginwindow.GuestEnabled  = false;
        NSGlobalDomain.AppleInterfaceStyle = "Dark";
        NSGlobalDomain.KeyRepeat = 0;
        NSGlobalDomain.AppleSpacesSwitchOnActivate=true;
        NSGlobalDomain.AppleShowAllExtensions = true;
        NSGlobalDomain.AppleShowAllFiles=true;
    };
    #for silicon needed so far
    environment.extraInit = ''
        #make sure brew is on the path for M1 
        if [[ $(uname -m) == 'arm64' ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
                fi
    '';
    environment.shells = [ pkgs.bashInteractive pkgs.zsh ];
    



    homebrew = {
        #this is where you put your repos (think apt repos) "koekeishiya/formulae")
        taps = [
            "koekeishiya/formulae"
        ];
        enable = true;
        global.autoUpdate = true;
        casks=[ "docker" "chromium" "raycast" "alt-tab" "zen-browser" "microsoft-azure-storage-explorer"  ]; 
        #this is where you would put a app from the repo "koekeishiya/formulae/skhd"
        brews = [
            "koekeishiya/formulae/yabai"
        ];
    };

    # bashtrue
    environment.etc.bashrc.text = builtins.readFile(../misc/.bashrc);
    environment.etc.inputrc.text = builtins.readFile(../misc/.inputrc);
    programs.bash = {
        enable = true;
        completion.enable =true;
        # interactiveShellInit = ''
        #     set -o vi
        #     eval "$(starship init bash)"
        # '';
    };
}
