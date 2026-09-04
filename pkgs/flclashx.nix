{ appimageTools, lib, fetchurl }:

let
  pname = "flclashx";
  version = "0.4.2";

  appimage = fetchurl {
    url = "https://github.com/pluralplay/FlClashX/releases/download/v${version}/FlClashX-linux-amd64.AppImage";
    sha256 = "sha256-jKqfL1kradD06uCrXxdpeJDRTvL65IF7S9A0I1CzA8I=";
  };

  # Extract once, and patch the Flutter AOT path the embedder expects
  # (it looks for libapp.so next to the executable, but it lives in usr/lib).
  appimageContents = appimageTools.extractType2 {
    inherit pname version;
    src = appimage;
    postExtract = ''
      ln -sf ../lib/libapp.so "$out/usr/bin/libapp.so"
      mkdir -p "$out/usr/bin/lib"
      ln -sf ../../lib/libapp.so "$out/usr/bin/lib/libapp.so"
    '';
  };
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  extraPkgs = pkgs: with pkgs; [
    # tray / systray (README: libayatana-appindicator3 + libkeybinder-3.0)
    libayatana-appindicator
    libayatana-indicator
    libayatana-ido
    libdbusmenu-gtk3
    keybinder
    # GTK3 / Flutter runtime closure (FHS env only symlinks direct outputs)
    gtk3
    libepoxy
    pango
    cairo
    harfbuzz
    fontconfig
    freetype
    libxkbcommon
    atk
    at-spi2-atk
    at-spi2-core
    dbus
    wayland
    libglvnd
    libxcomposite
    libxcursor
    libxi
    libxdamage
    libxinerama
    libxrandr
    libxtst
    libthai
    libdatrie
    graphite2
  ];

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/com.follow.clashx.desktop \
      $out/share/applications/com.follow.clashx.desktop
    install -Dm444 ${appimageContents}/FlClashX.png \
      $out/share/icons/hicolor/256x256/apps/FlClashX.png
    substituteInPlace $out/share/applications/com.follow.clashx.desktop \
      --replace-fail 'Exec=FlClashX' 'Exec=${pname}'
  '';

  meta = {
    description = "Fork of the multi-platform proxy client FlClash, based on Mihomo core";
    homepage = "https://github.com/pluralplay/FlClashX";
    license = lib.licenses.gpl3Only;
    mainProgram = pname;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
