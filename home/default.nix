{ ... }:

{
  home-manager = {
    users.ktvsky = {
	  imports = [
	    ./modules/default.nix
	  ];
	  programs.home-manager.enable = true;
	  home.stateVersion = "25.11";
    };
  };
}
