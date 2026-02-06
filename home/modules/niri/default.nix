{ flakeHost, ... }:
let
  baseConfig = builtins.readFile ./config.kdl;
  desktopOutputs = builtins.readFile ./desktop-outputs.kdl;
  finalConfig =
    if flakeHost == "desktop"
    then baseConfig + "\n\n" + desktopOutputs
    else baseConfig;
in
{
  xdg.configFile."niri/config.kdl".text = finalConfig;
}
