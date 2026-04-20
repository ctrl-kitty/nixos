{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    unstable.xwayland-satellite
    nautilus
  ];
  programs.niri.enable = true;

  xdg.portal = {
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };
}
