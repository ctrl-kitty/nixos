{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.proton-game ];
  environment.shellAliases.prun = "proton-game";

  programs.gamemode.enable = true;
  programs.steam = {
    enable = true;
  };
  programs.gamescope = {
    enable = true;
    capSysNice = false;
  };
}
