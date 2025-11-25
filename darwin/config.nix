{ config
, pkgs
, pkgs-unstable
, ...
}:

{
  imports = [
    ../modules/nvim.nix
    ./zsh.nix
    ./scripts.nix
  ];
  nix.settings.download-buffer-size = 524288000;
  system.stateVersion = 5;
  nix.enable = true;
  nixpkgs.config.allowUnfree = true;
  nix.package = pkgs.nix;
  nix.settings.experimental-features = "nix-command flakes";
  environment.systemPackages = with pkgs; [
    zsh
    pkgs-unstable.youtube-music
    pkgs-unstable.jetbrains.rider
    #needed for bash script
    findutils
    #dotnet-sdk
  ];
  users.users.ezekielenns = {
    name = "ezekielenns";
    home = "/Users/ezekielenns";
  };
  system.primaryUser = "ezekielenns";
  fonts.packages = [
    pkgs.nerd-fonts.monofur
  ];

  system.startup.chime = false;

  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = true;
      #https://daiderd.com/nix-darwin/manual/index.html#opt-system.defaults.dock.wvous-bl-corner
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
      expose-animation-duration = 0.0;
      tilesize = 25;
      autohide-time-modifier = 0.0;
      static-only = true;
      launchanim = false;
      show-recents = false;
      orientation = "bottom";
      appswitcher-all-displays = true;
    };
    controlcenter = {
      BatteryShowPercentage = true;
    };
    menuExtraClock.Show24Hour = false;
    finder.QuitMenuItem = true;
    finder.FXPreferredViewStyle = "clmv";
    finder.FXEnableExtensionChangeWarning = false;
    finder.CreateDesktop = false;
    loginwindow.GuestEnabled = false;
    NSGlobalDomain.AppleInterfaceStyle = "Dark";
    NSGlobalDomain.KeyRepeat = 0;
    NSGlobalDomain.AppleSpacesSwitchOnActivate = true;
    NSGlobalDomain.AppleShowAllExtensions = true;
    NSGlobalDomain.AppleShowAllFiles = true;
    NSGlobalDomain.AppleICUForce24HourTime = false;
    NSGlobalDomain._HIHideMenuBar = false;
  };
  #for silicon needed so far
  environment.extraInit = ''
     #make sure brew is on the path for M1 
     if [[ $(uname -m) == 'arm64' ]]; then
         eval "$(/opt/homebrew/bin/brew shellenv)"
     fi
     # add Docker CLI to PATH if it exists
    if [ -d "/Applications/Docker.app/Contents/Resources/bin/" ]; then
      export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin/"
    fi
  '';
  environment.shells = [ pkgs.zsh ];

  homebrew = {
    taps = [
      "koekeishiya/formulae"
    ];
    enable = true;
    global.autoUpdate = true;
    casks = [
      "docker"
      "chromium"
      "raycast"
      "zen-browser"
      "microsoft-azure-storage-explorer"
      "slack"
      "ghostty"
      "obs"
      "tailscale-app"
    ];
    brews = [
      "zellij"
      "direnv"
    ];
  };
}
