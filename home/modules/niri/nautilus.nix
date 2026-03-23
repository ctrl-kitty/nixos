{ ... }:
{
  dconf.settings = {
    "org/gnome/nautilus/preferences" = {
      always-use-location-entry = true;
      sort-directories-first = true;
      default-folder-viewer = "list-view";
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
    };
  };
}
