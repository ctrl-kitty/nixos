{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:

let
  # An absolute checkout path, not a Nix path copied into the read-only store.
  sharedMimeApps = config.lib.file.mkOutOfStoreSymlink (
    "${config.home.homeDirectory}/.dotfiles/nixos/home/modules/xdg/mimeapps.list"
  );

  nvimPkg =
    if (osConfig.programs.nixvim.package or null) != null then
      osConfig.programs.nixvim.package
    else if (osConfig.programs.nixvim.finalPackage or null) != null then
      osConfig.programs.nixvim.finalPackage
    else
      pkgs.neovim;

  nvimExe = lib.getExe nvimPkg;

  terminalCmd = config.home.sessionVariables.TERMINAL or (lib.getExe pkgs.wezterm);
in
{
  # Keep system fallbacks in modules/graphic/file-associations.nix, while GUI
  # choices write to the checkout and travel with it between hosts.
  xdg.mimeApps.enable = false;
  xdg.configFile."mimeapps.list".source = sharedMimeApps;
  xdg.dataFile."applications/mimeapps.list".source = sharedMimeApps;

  home.packages = [ pkgs.kdePackages.kate ];

  xdg.desktopEntries = lib.mkIf osConfig.programs.nixvim.enable {
    nvim = {
      name = "Neovim";
      genericName = "Text Editor";
      icon = "nvim";
      categories = [
        "Utility"
        "TextEditor"
      ];
      terminal = false;

      exec = "${lib.escapeShellArg terminalCmd} -e ${lib.escapeShellArg nvimExe} %F";

      mimeType = [
        "text/plain"
        "text/markdown"
        "application/json"
        "application/x-yaml"
        "application/x-shellscript"
      ];
    };
  };
}
