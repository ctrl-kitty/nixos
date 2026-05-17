{ ... }:
{
  xdg.portal.config = {
    niri = {
      # Put gnome first, then gtk
      default = [
        "gnome"
        "gtk"
      ];

      "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome" ];
    };
  };
}
