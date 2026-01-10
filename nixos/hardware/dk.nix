{ config
, lib
, pkgs
, modulesPath
, pkgs-unstable
, ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=pt"
    "processor.max_cstate=5"
    "idle=nomwait"
    "amdgpu.runpm=0"
    "amdgpu.gpu_recovery=1"
    "nvidia_drm.modeset=1"
  ];

  boot.extraModulePackages = [ ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernel.sysctl = {
    "kernel.panic" = 10;
    "kernel.panic_on_oops" = 1;
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/478e3c03-a6ba-4aa0-916b-d6c855fd3554";
    fsType = "ext4";
  };
  fileSystems."/run/media/ezekiel/games" = {
    device = "/dev/disk/by-uuid/a2c6c80f-93bb-41ad-8200-e5f77225c900";
    fsType = "ext4";
    options = [
      "defaults"
      "noatime"
      "rw"
      "exec"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/C53A-A01B";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/78e2e8b4-4894-4e8f-b835-2a525b7985ba"; }
  ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  services.xserver.enable = true;
  services.xserver.videoDrivers = [
    "amdgpu"
    "nvidia"
  ];

  hardware = {
    nvidia-container-toolkit.enable = true;
    #steam-hardware.enable = true;
    #show gpu temps  watch -n0.5 nvidia-smi
    # nix-shell -p pciutils --run "lspci | grep -E 'VGA|3D'"
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      prime = {
        offload.enable = true;
        amdgpuBusId = "PCI:15:0:0"; # from 0f:00.0
        nvidiaBusId = "PCI:1:0:0"; # from 01:00.0
      };
    };
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libva-vdpau-driver
        libvdpau-va-gl
      ];
    };
  };
  programs.steam.package = pkgs-unstable.steam;
  programs.gamescope.package = pkgs-unstable.gamescope;
  environment.systemPackages = with pkgs-unstable; [
    mangohud
    gamemode
  ];
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamescope.enable = true;

}
