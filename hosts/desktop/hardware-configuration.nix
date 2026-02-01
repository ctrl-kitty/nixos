# This file is a placeholder.
# Generate a real one on the desktop and replace this:
#   sudo nixos-generate-config --show-hardware-config
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = lib.mkDefault [ ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = lib.mkDefault [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = lib.mkDefault "/dev/disk/by-uuid/REPLACE-ME";
    fsType = lib.mkDefault "ext4";
  };

  fileSystems."/boot" = {
    device = lib.mkDefault "/dev/disk/by-uuid/REPLACE-ME";
    fsType = lib.mkDefault "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
