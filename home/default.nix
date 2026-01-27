{ inputs, ... }:

{
  home-manager = {
    users.ktvsky = {
	  imports = [
	    ./modules/default.nix
		inputs.nixcord.homeModules.nixcord
	  ];
	  programs.home-manager.enable = true;
	  home.stateVersion = "25.11";
    };
  };
}
