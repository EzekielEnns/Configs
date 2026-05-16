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
    # required by some games (Star Citizen, Hogwarts Legacy, Counter-Strike 2)
    "vm.max_map_count" = 2147483642;
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
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
    nvidia-container-toolkit.enable = true;
    steam-hardware.enable = true;
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
  # Broader gamepad coverage (PS5, 8BitDo, Xbox Elite, etc.) on top of the
  # Valve rules that steam-hardware.enable already installs.
  services.udev.packages = with pkgs; [ game-devices-udev-rules ];

  # Tell SDL to use its HIDAPI backend for Steam Controllers so non-Steam
  # games (Lutris, native Linux titles) can see the SC2 outside of Steam.
  # Harmless when no controller is connected.
  environment.sessionVariables = {
    SDL_HINT_JOYSTICK_HIDAPI_STEAM = "1";
    SDL_HINT_JOYSTICK_HIDAPI_STEAMDECK = "1";
  };

  # Wraps a command so it runs on the dGPU (NVIDIA). Usage: `nvidia-offload steam`
  # or set Steam per-game launch options to: nvidia-offload %command%
  environment.systemPackages = (with pkgs-unstable; [
    mangohud
    protonup-qt # GUI for managing Proton-GE versions
  ]) ++ [
    (pkgs.writeShellScriptBin "nvidia-offload" ''
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __VK_LAYER_NV_optimus=NVIDIA_only
      exec "$@"
    '')
  ];

  programs.steam = {
    enable = true;
    package = pkgs-unstable.steam;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = with pkgs-unstable; [ proton-ge-bin ];
  };

  programs.gamescope = {
    enable = true;
    package = pkgs-unstable.gamescope;
    capSysNice = true;
  };

  programs.gamemode = {
    enable = true;
    settings = {
      general.renice = 10;
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        nv_powermizer_mode = 1;
      };
    };
  };
}
