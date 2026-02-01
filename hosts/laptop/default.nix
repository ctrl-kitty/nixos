{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./graphics.nix
    ../../modules/power/profiles.nix
  ];

  networking.hostName = "RedNix";
}
