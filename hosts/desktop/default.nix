{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./graphics.nix
	./services.nix
  ];

  networking.hostName = lib.mkDefault "DeskNix";

}
