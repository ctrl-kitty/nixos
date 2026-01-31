{ config, pkgs, ... }:

{
	home.sessionVariables = {
		TERMINAL = "ghostty";
	};

	programs.fuzzel.enable = true;

	services.mako.enable = true;

	home.packages = [
		pkgs.hyprshell
	];

	xdg.configFile."hyprshell/config.ron".text = ''
		(
		  version: 3,
		  windows: (
		    switch: (
		      modifier: "alt",
		      key: "Tab",
		      filter_by: [current_monitor],
		      switch_workspaces: false,
		      exclude_special_workspaces: "",
		    ),
		  ),
		)
	'';

#	xdg.mimeApps = {
#		enable = true;
#		defaultApplications = {
#			"inode/directory" = "org.kde.dolphin.desktop";
#			"application/zip" = "org.kde.ark.desktop";
#			"application/x-7z-compressed" = "org.kde.ark.desktop";
#			"application/x-rar" = "org.kde.ark.desktop";
#			"application/x-tar" = "org.kde.ark.desktop";
#			"application/gzip" = "org.kde.ark.desktop";
#			"application/x-bzip2" = "org.kde.ark.desktop";
#			"application/x-xz" = "org.kde.ark.desktop";
#		};
#	};

	wayland.windowManager.hyprland = {
		enable = true;
		package = null;
		portalPackage = null;

		settings = {
			"$mod" = "SUPER";
			"$terminal" = config.home.sessionVariables.TERMINAL;
			"$filemanager" = "dolphin";

			general = {
				gaps_in = 6;
				gaps_out = 4;
				border_size = 2;
			};

			decoration = {
				rounding = 10;
				shadow = {
					enabled = true;
					range = 24;
					render_power = 3;
				};
				blur = {
					enabled = true;
					size = 6;
					passes = 3;
					new_optimizations = true;
				};
			};

			misc = {
				disable_hyprland_logo = true;
				disable_splash_rendering = true;
				force_default_wallpaper = 0;
			};

			animations = {
				enabled = true;
				bezier = [
					"easeOut, 0.05, 0.9, 0.1, 1.0"
				];
				animation = [
					"windows, 1, 4, easeOut, slide"
					"windowsOut, 1, 4, easeOut, slide"
					"border, 1, 6, easeOut"
					"fade, 1, 4, easeOut"
					"workspaces, 1, 3, easeOut, slide"
				];
			};

			bind = [
				"$mod, Return, exec, $terminal"
				"$mod, R, exec, fuzzel"
				"$mod SHIFT, S, exec, grim -g \"$(slurp)\" - | wl-copy -t image/png"
				"$mod, Q, killactive"
				"$mod, E, exec, $filemanager"
				"$mod, V, togglefloating"
				"$mod, 1, workspace, 1"
				"$mod, 2, workspace, 2"
				"$mod, 3, workspace, 3"
				"$mod, 4, workspace, 4"
				"$mod, 5, workspace, 5"
				"$mod, 6, workspace, 6"
				"$mod, 7, workspace, 7"
				"$mod, 8, workspace, 8"
				"$mod, 9, workspace, 9"
				"$mod, 0, workspace, 10"
				"$mod SHIFT, 1, movetoworkspace, 1"
				"$mod SHIFT, 2, movetoworkspace, 2"
				"$mod SHIFT, 3, movetoworkspace, 3"
				"$mod SHIFT, 4, movetoworkspace, 4"
				"$mod SHIFT, 5, movetoworkspace, 5"
				"$mod SHIFT, 6, movetoworkspace, 6"
				"$mod SHIFT, 7, movetoworkspace, 7"
				"$mod SHIFT, 8, movetoworkspace, 8"
				"$mod SHIFT, 9, movetoworkspace, 9"
				"$mod SHIFT, 0, movetoworkspace, 10"
				"$mod, left, movefocus, l"
				"$mod, right, movefocus, r"
				"$mod, up, movefocus, u"
				"$mod, down, movefocus, d"
			];

			bindel = [
				",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
				",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
				",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
				",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
				",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
				",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
			];

			"exec-once" = [
				"${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
				"${pkgs.mako}/bin/mako"
				"${pkgs.hyprpaper}/bin/hyprpaper"
				"${pkgs.hyprshell}/bin/hyprshell run &"
			];
		};
	};
}
