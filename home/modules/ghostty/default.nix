{ ... }:
{
  programs.ghostty = {
    enable = true;
	enableZshIntegration = true;
	systemd.enable = true;
	settings = {
	  scrollback-limit = 100000;
	  mouse-hide-while-typing = true;
	  link-url = true;
	  link-previews = true;
	  selection-clear-on-copy = false;
	  minimum-contrast = 1.1;
	};
  };
}
