{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./graphics.nix
  ];

  networking.hostName = lib.mkDefault "DeskNix";

  home-manager.users.ktvsky.wayland.windowManager.hyprland.settings = {
    monitor = [
      "HDMI-A-1, 1920x1080@60, 0x0, 1"
      "DP-1, 3840x2160@60, 1920x-360, 1"
    ];

    workspace = [
      "1, monitor:DP-1, default:true"
    ];
  };
}
