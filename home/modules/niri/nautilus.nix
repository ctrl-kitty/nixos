{ ... }:
{
  dconf.settings = {
    "org/gnome/nautilus/preferences" = {
      always-use-location-entry = true;
      sort-directories-first = true;
      default-folder-viewer = "list-view";
      show-hidden-files = true;
    };
    # GTK file chooser dialogs (open/save)
    "org/gtk/gtk4/settings/file-chooser" = {
      show-hidden = true;
    };
    "org/gtk/settings/file-chooser" = {
      show-hidden = true;
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
    };
  };
}
