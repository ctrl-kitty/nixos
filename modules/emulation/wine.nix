{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    unstable.wineWow64Packages.staging
    unstable.winetricks
  ];
}
