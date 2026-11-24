{
  appimageTools,
  lib,
  fetchurl,
  symlinkJoin,
  writeShellScript,
}:

let
  pname = "genoffice";
  version = "0.12.115";

  src = fetchurl {
    url = "https://github.com/genspark-ai/genoffice/releases/download/v${version}/GenOffice-${version}.AppImage";
    hash = "sha256-d1BhPN5HGJKhKaWG1O8kD2CoFVvgqToM+EmK8XpTmyg=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };

  # GUI. On every launch it symlinks its bundled CLI launcher into the first
  # writable user bin dir; that launcher runs Electron outside the FHS env and
  # can't load its libraries, so point the link off PATH.
  app = appimageTools.wrapType2 {
    pname = "genoffice-app";
    inherit version src;
    profile = ''
      export XDG_BIN_HOME="$HOME/.genoffice/bin"
    '';
  };

  # Upstream's `genoffice` command: the bundled CLI on the app's own Node runtime.
  # It strips ELECTRON_RUN_AS_NODE before spawning GENOFFICE_APP_BIN.
  cli = appimageTools.wrapAppImage {
    inherit pname version;
    src = appimageContents;
    runScript = writeShellScript "genoffice-cli" ''
      export ELECTRON_RUN_AS_NODE=1
      export GENOFFICE_APP_BIN=${app}/bin/genoffice-app
      exec ${appimageContents}/genoffice ${appimageContents}/resources/cli/genoffice.cjs "$@"
    '';
  };
in
symlinkJoin {
  name = "${pname}-${version}";
  inherit pname version;
  paths = [
    app
    cli
  ];

  postBuild = ''
    install -Dm444 ${appimageContents}/genoffice.desktop \
      $out/share/applications/genoffice.desktop
    cp -r ${appimageContents}/usr/share/icons $out/share/icons
    cp -r ${appimageContents}/usr/share/mime $out/share/mime
    substituteInPlace $out/share/applications/genoffice.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=genoffice-app %U'
  '';

  meta = {
    description = "AI-powered office suite for docx, xlsx, pptx, PDF and Markdown";
    homepage = "https://github.com/genspark-ai/genoffice";
    license = lib.licenses.asl20;
    mainProgram = pname;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
