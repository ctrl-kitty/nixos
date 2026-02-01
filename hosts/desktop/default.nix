{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./graphics.nix
  ];

  networking.hostName = lib.mkDefault "DeskNix";
}
