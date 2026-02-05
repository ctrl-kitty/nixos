{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.brightnessctl ];
  programs.niri.enable = true;
}
