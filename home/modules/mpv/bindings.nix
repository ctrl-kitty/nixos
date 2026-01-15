{ pkgs, ... }:
{
	programs.mpv = {
	  enable = true;
	  bindings = {
		LEFT = "seek -5";
		RIGHT = "seek 5";
		WHEEL_UP = "add volume 2";
		WHEEL_DOWN = "add volume -2";
		"Ctrl+WHEEL_UP" = "add speed 0.1";
		"Ctrl+WHEEL_DOWN" = "add speed -0.1";
	  };
	};

}
