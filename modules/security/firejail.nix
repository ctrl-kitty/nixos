{ pkgs, ... }:
{
  programs.firejail = {
    enable = true;
    wrappedBinaries = {
  #    signal-desktop = {
  #      # Enable tray icon otherwise Signal window might be hidden
  #      executable = "${pkgs.signal-desktop}/bin/signal-desktop --use-tray-icon";
  #      profile = "${pkgs.firejail}/etc/firejail/signal-desktop.profile";
  #      extraArgs = [
  #        # Enforce dark mode
  #        "--env=GTK_THEME=Adwaita:dark"
  #        # Enable Wayland mode
  #        "--env=NIXOS_OZONE_WL=1"
  #        # Allow tray icon (should be upstreamed into signal-desktop.profile)
  #        "--dbus-user.talk=org.kde.StatusNotifierWatcher"
  #      ];
  #  };
    };
  };
}
