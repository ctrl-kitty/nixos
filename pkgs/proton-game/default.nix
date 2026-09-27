{
  writeShellApplication,
  python3,
  fzf,
  steam-run,
}:

writeShellApplication {
  name = "proton-game";
  runtimeInputs = [
    python3
    fzf
    steam-run
  ];
  text = ''
    exec python3 ${./launcher.py} "$@"
  '';
  derivationArgs.postCheck = ''
    PROTON_GAME_SOURCE=${./launcher.py} PYTHONDONTWRITEBYTECODE=1 \
      ${python3}/bin/python3 ${./test_launcher.py}
  '';
  meta = {
    description = "Choose and launch a Windows game from the current directory with Proton";
    mainProgram = "proton-game";
    platforms = [ "x86_64-linux" ];
  };
}
