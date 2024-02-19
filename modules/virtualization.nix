{...}:
{

    virtualisation.libvirtd.enable = true;
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };
}
