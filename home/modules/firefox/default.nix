{ ... }:
{
  programs.firefox = {
	enable = true;
	profiles = {
	  default = { extensions.force = true; };
	  };
  };
  home.file.".mozilla/firefox/profiles.ini".force = true;
  stylix.targets.firefox.profileNames = ["default"];
  stylix.targets.firefox.colorTheme.enable = true;
}
