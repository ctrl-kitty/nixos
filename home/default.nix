{ inputs, ... }:

{
  home-manager = {
    users.ktvsky = {
	  imports = [
	    ./modules/default.nix
		inputs.nixcord.homeModules.nixcord
	    inputs.noctalia.homeModules.default
	  ];
	  programs.home-manager.enable = true;
	  home.stateVersion = "25.11";
    };
  };
}
