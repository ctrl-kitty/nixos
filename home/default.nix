{ config, pkgs, ... }:

{
  home-manager.users.ktvsky = {
    imports = [
	  ./mpv/default.nix
    ];
    programs.home-manager.enable = true;
    home.stateVersion = "25.11";
  };
}
