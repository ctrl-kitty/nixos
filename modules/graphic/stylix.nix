{ pkgs, ... }:
{
  # QT_QPA_PLATFORMTHEME=qt5ct setted here
  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = ./base16.yaml;
    cursor = {
      size = 24;
      package = pkgs.kdePackages.breeze;
      name = "breeze_cursors";
    };
    fonts = {
      monospace = {
        name = "JetBrainsMono Nerd Font";
        package = pkgs.nerd-fonts.jetbrains-mono;
      };
    };
  };
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    hicolor-icon-theme
  ];
}
