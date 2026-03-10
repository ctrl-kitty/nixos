{
  lib,
  config,
  pkgs,
  ...
}:
{

  home.activation = {
    # Must run before checkLinkTargets (collision detection), NOT just writeBoundary
    removeVscodeFiles = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      rm -f "${config.xdg.configHome}/Code/User/settings.json"
      rm -f "${config.xdg.configHome}/Code/User/keybindings.json"
    '';

    vscodeSymlinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      dotfilesDir="/home/ktvsky/.dotfiles/nixos/home/modules/vscode"
      vscodeDir="${config.xdg.configHome}/Code/User"
      rm -f "$vscodeDir/settings.json"
      ln -sf "$dotfilesDir/settings.json" "$vscodeDir/settings.json"
      rm -f "$vscodeDir/keybindings.json"
      ln -sf "$dotfilesDir/keybindings.json" "$vscodeDir/keybindings.json"
    '';
  };
  programs.vscode = {
    enable = true;
    # package = pkgs.vscode.fhs;
    profiles.default = {
      enableUpdateCheck = false;
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
        ms-python.python
        ms-python.vscode-pylance
        ms-python.debugpy
        ms-dotnettools.csdevkit
        visualstudiotoolsforunity.vstuc
        ms-azuretools.vscode-containers
        mhutchie.git-graph
        ms-vscode-remote.remote-containers
        yzhang.markdown-all-in-one
      ];

    };

  };
}
