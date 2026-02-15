{ ... }:
{
  imports = [
	./mpv/default.nix
	./ghostty/default.nix
# 	./hyprland/default.nix
	./firefox/default.nix
	./nixcord/default.nix
	./niri/default.nix
	./noctalia/default.nix
	./throne/default.nix
	# https://discourse.nixos.org/t/dolphin-does-not-have-mime-associations/48985/12 
	# piece of plasma
	./xdg/mimeapps.nix
  ];
}
