{ config
, pkgs
, lib
, ...
}:
{
  networking.hostName = "mini";

  # Enable early networking & NFS in initrd so we can mount root over NFS
  boot.initrd.network.enable = true;
  boot.supportedFilesystems = [ "nfs" ];

  # Adjust IP/path to your dk server & export path below
  boot.kernelParams = [
    "ip=dhcp"
    "root=/dev/nfs"
    "nfsroot=192.168.1.6:/srv/nfs/mini,vers=3"
  ];

  # Optional: declare rootfs too (some people like both)
  # fileSystems."/" = {
  #   device = "192.168.1.6:/srv/nfs/mini";
  #   fsType = "nfs";
  #   options = [ "noatime" "vers=3" ];
  # };

  services.openssh.enable = true;
  users.users.ezekiel = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      # your SSH pubkey here
    ];
  };

  # Keep the image svelte for a weak client
  documentation.enable = lib.mkForce false;
}
