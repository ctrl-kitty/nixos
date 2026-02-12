{ pkgs, ... }:

{
	programs.hyprland.enable = true;

	security.polkit.enable = true;

	environment.systemPackages = with pkgs; [
		fuzzel
		hyprpaper
		grim
		slurp
		wl-clipboard
		mako
		polkit_gnome
		kdePackages.ark
		unrar
		kdePackages.dolphin
	];
}
