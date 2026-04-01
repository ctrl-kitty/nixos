{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    #    wineWowPackages.waylandFull
    unstable.wineWowPackages.staging
    unstable.winetricks
  ];
}
