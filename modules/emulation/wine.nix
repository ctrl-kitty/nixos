{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
#    wineWowPackages.waylandFull
    wineWowPackages.staging
    winetricks
  ];
}
