{ flakeHost, pkgs, ... }:
let
  baseConfig = builtins.readFile ./config.kdl;
  desktopOutputs = builtins.readFile ./desktop-outputs.kdl;
  laptopConfig = builtins.readFile ./laptop.kdl;
  finalConfig =
    if flakeHost == "desktop" then
      baseConfig + "\n\n" + desktopOutputs
    else if flakeHost == "laptop" then
      baseConfig + "\n\n" + laptopConfig
    else
      baseConfig;
in
{
  imports = [
    ./swaylock.nix
  ];
  xdg.configFile."niri/config.kdl".text = finalConfig;

  home.sessionVariables = {
    TERMINAL = "ghostty";
    NIXOS_OZONE_WL = "1";
  };

  #programs.fuzzel.enable = true;
  programs.anyrun = {
    enable = true;
    config = {
      x = {
        fraction = 0.5;
      };
      y = {
        fraction = 0.3;
      };
      width = {
        fraction = 0.3;
      };
      maxEntries = 20;
      # buggy
      # closeOnClick = true;
      plugins = [
        "${pkgs.anyrun}/lib/libapplications.so"
        "${pkgs.anyrun}/lib/libwebsearch.so"
        "${pkgs.anyrun}/lib/libnix_run.so"
      ];
    };
    extraCss = /* css */ ''
      window {
        border-radius: 24px;
        padding: 14px;
      }

      .main {
        border-radius: 20px;
        padding: 4px;
      }

      text {
        min-height: 30px;
        border-radius: 999px;
        padding: 0 14px;
        margin: 0 0 10px 0;
      }

      .matches {
        margin: 0;
        padding: 0;
      }

      .plugin {
        margin: 0 0 4px 0;
        padding: 0;
      }

      .plugin:last-child {
        margin-bottom: 0;
      }

      .plugin .info {
        margin-bottom: 4px;
        padding: 0 4px;
      }

      .plugin .info image {
        margin-right: 8px;
      }

      .plugin .info label {
        font-weight: 600;
      }

      .match {
        border-radius: 14px;
        padding: 4px 8px;
        margin: 2px 0;
      }

      .match image {
        margin-right: 10px;
      }

      .match .title {
        font-weight: 600;
        margin-bottom: 1px;
      }

      .match .description {
        font-size: 0.92em;
      }
    '';
  };
}
