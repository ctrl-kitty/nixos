{
  pkgs,
  config,
  lib,
  osConfig,
  ...
}:
let
  warnNoVesktop = lib.warnIf (!config.programs.nixcord.vesktop.enable)
    "Vesktop is configured for autostart (vesktop --start-minimized) but nixcord vesktop is not enabled (programs.nixcord.vesktop.enable = true). Either enable it or remove the entry.";

  mkAutostartService = { name, description, exec }:
    lib.nameValuePair "${name}-autostart" {
      Unit = {
        Description = description;
        After = [ "graphical-session.target" "noctalia.service" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "exec";
        ExecStartPre = "${pkgs.glib.bin}/bin/gdbus wait --session org.kde.StatusNotifierWatcher --timeout 20";
        ExecStart = exec;
        Restart = "no";
        TimeoutStopSec = 5;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
in
{
  systemd.user.services = lib.listToAttrs [
    (mkAutostartService {
      name = "throne";
      description = "Throne";
      exec = "${osConfig.programs.throne.package}/bin/Throne -tray -appdata";
    })
    (mkAutostartService {
      name = "ayugram";
      description = "AyuGram Desktop";
      exec = "${pkgs.ayugram-desktop}/bin/AyuGram -startintray";
    })
    (warnNoVesktop (mkAutostartService {
      name = "vesktop";
      description = "Vesktop";
      exec = "${config.programs.nixcord.finalPackage.vesktop}/bin/vesktop --start-minimized";
    }))
  ];

  home.activation.cleanupStaleAutostart = config.lib.dag.entryAfter ["linkGeneration"] ''
    rm -f "$HOME/.config/autostart/Throne.desktop"
  '';
}
