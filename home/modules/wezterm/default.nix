{ pkgs, ... }:
{
  programs.wezterm = {
    enable = true;
	package = pkgs.unstable.wezterm;
    enableZshIntegration = true;
    extraConfig = builtins.readFile ./wezterm.lua;
  };
}
