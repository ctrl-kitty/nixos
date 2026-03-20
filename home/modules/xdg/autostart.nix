{
  pkgs,
  config,
  osConfig,
  ...
}:
let
  replaceExec =
    package: name: newExec:
    (pkgs.runCommand name { } ''
      mkdir -p $out
      src=${package}/share/applications/${name}
      sed 's|^Exec=.*$|Exec=${newExec}|' "$src" > $out/${name}
    '')
    + /${name};
in
{
  # Use program.package if can be to respect hidden login
  xdg.autostart = {
    enable = true;
    entries = [
      (replaceExec osConfig.programs.throne.package "throne.desktop" "Throne -tray -appdata")
      (replaceExec pkgs.ayugram-desktop "com.ayugram.desktop.desktop" "AyuGram -autostart")
      (replaceExec config.programs.nixcord.finalPackage.vesktop "vesktop.desktop"
        "vesktop --start-minimized"
      )
    ];
  };
}
