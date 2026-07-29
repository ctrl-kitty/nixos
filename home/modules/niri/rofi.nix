{ lib, ... }:
{
  programs.rofi = {
    enable = true;
    terminal = "wezterm";
    cycle = true;
    font = lib.mkForce "JetBrainsMono Nerd Font Bold 10";
    extraConfig = {
      show-icons = true;

      border = 2;
      padding = 10;

      spacing = 8;

      # Hide android (waydroid) app entries
      drun-exclude-categories = "X-WayDroid-App";
    };
    theme = lib.mkAfter {
      "*" = {
        border-radius = 12;
      };

      inputbar = {
        padding = 8;
        border-radius = 10;
      };

      entry = {
        padding = 6;
      };

      element = {
        padding = 8;
        border-radius = 10;
      };

      element-icon = {
        size = 24;
        margin = "0 14px 0 0";
      };

      element-text = {
        vertical-align = "0.5";
      };
    };
  };
}
