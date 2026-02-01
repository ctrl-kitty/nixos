{ ... }:
{
  services.xserver.videoDrivers = [ "amdgpu" ];

  environment.sessionVariables = {
    VDPAU_DRIVER = "radeonsi";
    LIBVA_DRIVER_NAME = "radeonsi";
  };
}
