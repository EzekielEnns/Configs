{ config
, pkgs
, lib
, modulesPath
, ...
}:
let
  # A tiny "session package" that the DM can recognize
  thinX2GoSession = pkgs.stdenv.mkDerivation {
    name = "thin-x2go-session";
    phases = [ "installPhase" ];
    installPhase = ''
            mkdir -p "$out/share/xsessions"
            cat > "$out/share/xsessions/thin-x2go.desktop" <<'EOF'
      [Desktop Entry]
      Name=Thin X2Go
      Comment=Auto-connect to dk via X2Go
      Exec=${pkgs.x2goclient}/bin/x2goclient --thinclient --fullscreen --geometry=auto --link=lan --clipboard --sound=alsa --username=ezekiel --host=192.168.1.6
      Type=Application
      EOF
    '';
    passthru.providedSessions = [ "thin-x2go" ];
  };
in
{
  imports = [
    (modulesPath + "/installer/netboot/netboot-minimal.nix")
  ];

  system.stateVersion = "25.05"; # silence the warning; pin to your channel

  networking.hostName = lib.mkForce "mini-thin";

  services.xserver.enable = true;

  # LightDM (enable path lives under xserver)
  services.xserver.displayManager.lightdm.enable = true;

  # Autologin lives under services.displayManager.*
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "ezekiel";

  # Tell the DM what session we provide and set it as the default
  services.displayManager.sessionPackages = [ thinX2GoSession ];
  services.displayManager.defaultSession = "thin-x2go"; # must match the .desktop name

  networking.networkmanager.enable = true;

  users.users.ezekiel = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "audio"
      "video"
      "input"
      "networkmanager"
    ];
    initialPassword = "change-me-now";
  };

  environment.systemPackages = with pkgs; [ x2goclient ];

  # keep tiny
  documentation.enable = lib.mkForce false;
  documentation.nixos.enable = lib.mkForce false;
  documentation.man.enable = lib.mkForce false;
}
