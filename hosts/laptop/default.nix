{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./graphics.nix
    ../../modules/power/profiles.nix
  ];
  environment.systemPackages = with pkgs; [ unityhub]; 
  networking.hostName = "RedNix";
}
