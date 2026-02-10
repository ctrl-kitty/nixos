{ pkgs, ... }:
{
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.amdgpu.opencl.enable = true;

  hardware.graphics.extraPackages = with pkgs; [
    libva
    libva-utils
    libva-vdpau-driver
    libvdpau-va-gl
  ];
  hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [
    libva-vdpau-driver
    libvdpau-va-gl
  ];

  environment.sessionVariables = {
    VDPAU_DRIVER = "radeonsi";
    LIBVA_DRIVER_NAME = "radeonsi";
  };
  # some fps boost, but I don't want to make it possibly unstable
  # hardware.graphics.package = pkgs.unstable.mesa;
}
