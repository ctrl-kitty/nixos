{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./graphics.nix
    ./memory.nix
    ../../modules/power/profiles.nix
  ];
  environment.systemPackages = with pkgs; [ unityhub]; 
  networking.hostName = "RedNix";
}
