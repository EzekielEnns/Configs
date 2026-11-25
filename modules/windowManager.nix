{ config
, pkgs
, pkgs-unstable
, inputs
, ...
}:
{
  # Desktop
  services.xserver.enable = true;
  services.xserver.desktopManager = {
    xterm.enable = false;
  };
  # services.displayManager = { defaultSession = "none+i3"; };
  nixpkgs.config.permittedInsecurePackages = [
    "electron-25.9.0"
  ];
  services.xserver.displayManager.setupCommands = ''
    /run/current-system/sw/bin/xset -dpms
    /run/current-system/sw/bin/xset s off
  '';
  programs.dconf.enable = true;
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
  };
  services.displayManager = {
    gdm = {
      enable = true;
      # Auto-login only covers the first login after boot. Timed login also logs
      # straight back in after a logout or a crashed session, with no password.
      settings.daemon = {
        TimedLoginEnable = true;
        TimedLogin = config.services.displayManager.autoLogin.user;
        TimedLoginDelay = 1;
      };
    };
    autoLogin = {
      user = "ezekiel";
      enable = true;
    };
  };
  # No lock screen: nobody types a password at the desktop. Locked so a stray
  # user setting can't turn it back on.
  programs.dconf.profiles.user.databases = [
    {
      lockAll = true;
      settings = {
        "org/gnome/desktop/screensaver".lock-enabled = false;
        "org/gnome/desktop/lockdown".disable-lock-screen = true;
      };
    }
  ];
  services.desktopManager.gnome.enable = true;
}
