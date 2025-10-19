# nixos/mini-thin.nix
{ config
, pkgs
, lib
, modulesPath
, ...
}:
{
  imports = [
    # give us kernel+initrd outputs suitable for netboot-style images
    (modulesPath + "/installer/netboot/netboot-minimal.nix")
  ];

  # keep it minimal and fast to boot
  networking.hostName = "mini-thin";

  # graphics + a tiny X session that runs only X2Go client
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true; # tiny DM, boots straight into a session
    desktopManager.xterm.enable = true; # minimal fallback
    # Autologin -> custom session runs x2goclient
    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = "ezekiel";
    desktopManager.session = [
      {
        name = "thin-x2go";
        start = ''
          #!${pkgs.runtimeShell}
          # Launch x2go client full screen to your desktop (dk)
          ${pkgs.x2goclient}/bin/x2goclient \
            --thinclient \
            --fullscreen \
            --geometry=auto \
            --session="dk" \
            --add-to-known-hosts \
            --sound=alsa \
            --clipboard \
            --dpi=auto \
            --link=lan \
            --ssh-port=22 \
            --username=ezekiel \
            --passwdfile=/etc/x2go/pass \
            --host=192.168.1.6
        '';
      }
    ];
  };

  # Autologin user
  users.users.ezekiel = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "audio"
      "video"
      "input"
      "networkmanager"
    ];
    # For first boot, set a throwaway; you can switch to ssh-key auth later
    initialPassword = "change-me-now";
  };

  # Let NetworkManager manage the link (easy wifi if you want later)
  networking.networkmanager.enable = true;

  # X2Go client + small extras
  environment.systemPackages = with pkgs; [ x2goclient ];

  # Optional: disable the bulk of docs to keep image tiny
  documentation.enable = lib.mkForce false;

  # If you *also* want to NFS-mount /home from dk for local editors, add:
  # fileSystems."/home/ezekiel" = {
  #   device = "192.168.1.6:/srv/home/ezekiel";
  #   fsType = "nfs";
  #   options = [ "noatime" "vers=3" ];
  # };
}
