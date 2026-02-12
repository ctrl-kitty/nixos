{ flakeHost, ... }:
let
  baseConfig = builtins.readFile ./config.kdl;
  desktopOutputs = builtins.readFile ./desktop-outputs.kdl;
  laptopConfig = builtins.readFile ./laptop.kdl;
  finalConfig =
    if flakeHost == "desktop" then
      baseConfig + "\n\n" + desktopOutputs
    else if flakeHost == "laptop" then
      baseConfig + "\n\n" + laptopConfig
    else
      baseConfig;
in
{
  imports = [
    ./swaylock.nix
  ];
  xdg.configFile."niri/config.kdl".text = finalConfig;
}
