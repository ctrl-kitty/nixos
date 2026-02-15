

{ config, osConfig, pkgs, lib, ... }:

let
  nvimPkg =
    if (osConfig.programs.nixvim.package or null) != null then osConfig.programs.nixvim.package
    else if (osConfig.programs.nixvim.finalPackage or null) != null then osConfig.programs.nixvim.finalPackage
    else pkgs.neovim;

  nvimExe = lib.getExe nvimPkg;

  terminalCmd = config.home.sessionVariables.TERMINAL
  or (lib.getExe pkgs.ghostty);
in
{
  xdg.mimeApps.enable = true;
  xdg.configFile."mimeapps.list".force = true;
  xdg.desktopEntries = lib.mkIf osConfig.programs.nixvim.enable {
    nvim = {
      name = "Neovim";
      genericName = "Text Editor";
      icon = "nvim";
      categories = [ "Utility" "TextEditor" ];
      terminal = false;

      exec = "${lib.escapeShellArg terminalCmd} -e ${lib.escapeShellArg nvimExe}";

      mimeType = [
        "text/plain"
        "text/markdown"
        "application/json"
        "application/x-yaml"
        "application/x-shellscript"
      ];
    };
  };

  xdg.mimeApps.defaultApplications = lib.mkMerge [
    (lib.mkIf config.programs.mpv.enable {
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "video/mpeg" = "mpv.desktop";
    })

    (lib.mkIf osConfig.programs.nixvim.enable {
      "text/plain" = "nvim.desktop";
      "text/markdown" = "nvim.desktop";
      "application/json" = "nvim.desktop";
      "application/x-yaml" = "nvim.desktop";
      "application/x-shellscript" = "nvim.desktop";
    })
  ];

  xdg.mimeApps.associations.added = lib.mkMerge [
    (lib.mkIf config.programs.mpv.enable {
      "video/mp4" = [ "mpv.desktop" ];
      "video/x-matroska" = [ "mpv.desktop" ];
    })
    (lib.mkIf osConfig.programs.nixvim.enable {
      "text/plain" = [ "nvim.desktop" ];
    })
  ];
}
