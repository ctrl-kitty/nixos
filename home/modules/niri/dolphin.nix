{ pkgs, ... }:
{
  home.packages = with pkgs.kdePackages; [
    dolphin
    kde-cli-tools # File association editor (keditfiletype).
    qtsvg
  ];

  dconf.settings = {
    # GTK file chooser dialogs (open/save)
    "org/gtk/gtk4/settings/file-chooser" = {
      show-hidden = true;
    };
    "org/gtk/settings/file-chooser" = {
      show-hidden = true;
    };
  };
}
