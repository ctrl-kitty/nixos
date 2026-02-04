{ config, pkgs, ... }:

{
  home.sessionVariables = {
    TERMINAL = "ghostty";
    NIXOS_OZONE_WL = "1";
  };

  programs.fuzzel.enable = true;

  services.mako.enable = true;
  services.hyprshell = {
    enable = true;
    package = pkgs.hyprshell.overrideAttrs (
      final: prev: {
        # https://github.com/H3rmt/hyprshell/issues/372
        src = pkgs.fetchFromGitHub {
          owner = "H3rmt";
          repo = "hyprshell";
          rev = "69011f802ebfd14e710f9cccd6f856ce2e0d4c40";
          hash = "sha256-nemSN4dqwKKTqHyRwFKpEf54PPoHUvhCtrRBvasXEVg=";
        };
        cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
          src = final.src;
          hash = "sha256-g23W5cgGxWNyJ4uew2x12vgF5Bvaid1+phV2fxyHbas=";
        };
        # Unnecessary due to cargoDeps having higher priority than cargoHash,
        # but to make it explicitly that cargoHash is not used after overrideAttrs.
        cargoHash = null;
      }
    );
    settings = {
      windows = {
        scale = 8.0;
        overview = {
          launcher = {
            max_items = 6;
          };
        };
        switch = {
          modifier = "alt";
        };
      };
    };
  };
  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    settings = {
      xwayland.force_zero_scaling = true;

      "$mod" = "SUPER";
      "$terminal" = config.home.sessionVariables.TERMINAL;
      "$filemanager" = "dolphin";

      input = {
        kb_layout = "us,ru";
        kb_options = "grp:alt_shift_toggle";
      };

      general = {
        gaps_in = 6;
        gaps_out = 4;
        border_size = 1;
      };

      decoration = {
        rounding = 10;
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

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
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
      ];
    };
  };
}
