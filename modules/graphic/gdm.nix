{
  lib,
  pkgs,
  ...
}:
let
  loginCss = pkgs.writeText "gdm-minimal.css" ''
    #lockDialogGroup {
      background-color: #161616;
      background-image: none;
    }

    .login-dialog {
      background-color: transparent;
      color: #eeeeec;
    }

    .login-dialog-user-selection-box,
    .login-dialog > .login-dialog-prompt-layout {
      background-color: transparent;
      border: none;
      padding: 0;
      spacing: 1.25em;
      box-shadow: none;
    }

    .login-dialog .login-dialog-prompt-layout,
    .login-dialog-user-list-view {
      width: 22em;
    }

    .login-dialog .user-widget.vertical .user-icon {
      icon-size: 4.5em;
      background-color: #252525;
      box-shadow: none;
    }

    .login-dialog .user-widget.vertical .user-icon StIcon {
      padding: 1em;
    }

    .login-dialog .user-widget.vertical .user-widget-label {
      font-size: 1.2em;
      font-weight: 500;
      color: #eeeeec;
    }

    .login-dialog .login-dialog-user-list-item {
      background-color: transparent;
      border: 1px solid transparent;
      border-radius: 0.5em;
      padding: 0.85em 1em;
      color: #eeeeec;
    }

    .login-dialog .login-dialog-user-list-item:hover {
      background-color: #222222;
    }

    .login-dialog .login-dialog-user-list-item:focus,
    .login-dialog .login-dialog-user-list-item:selected {
      background-color: #222222;
      border-color: #b9b9b5;
      color: #eeeeec;
    }

    .login-dialog .login-dialog-prompt-entry {
      background-color: #202020;
      color: #eeeeec;
      border: 1px solid #50504d;
      border-radius: 0.4em;
      padding: 0.8em 1em;
      selection-background-color: #d6d6d0;
      selected-color: #161616;
    }

    .login-dialog .login-dialog-prompt-entry:focus {
      background-color: #202020;
      border-color: #d6d6d0;
      box-shadow: none;
    }

    .login-dialog .login-dialog-button {
      background-color: #252525;
      color: #eeeeec;
      border: 1px solid transparent;
      border-radius: 0.4em;
    }

    .login-dialog .login-dialog-button:hover,
    .login-dialog .login-dialog-button:focus {
      background-color: #303030;
      border-color: #b9b9b5;
      box-shadow: none;
    }

    .login-dialog-not-listed-label,
    .login-dialog-message-hint {
      color: #b2b2ac;
    }

    .login-dialog .caps-lock-warning-label,
    .login-dialog .login-dialog-message-warning {
      color: #e8bd86;
    }

    #panel.login-screen {
      background-color: #161616;
      color: #b2b2ac;
      border: none;
      box-shadow: none;
    }
  '';
  # Extend the installed Shell's CSS so selectors and assets match its version.
  # Leave the high-contrast resource untouched for the accessibility toggle.
  theme =
    pkgs.runCommand "gdm-minimal-theme"
      {
        nativeBuildInputs = [ pkgs.glib.dev ];
      }
      ''
        mkdir -p "$out"
        for variant in light dark; do
          gresource extract \
            ${pkgs.gnome-shell}/share/gnome-shell/gnome-shell-theme.gresource \
            /org/gnome/shell/theme/gnome-shell-$variant.css \
            > "$out/gnome-shell-$variant.css"
          cat ${loginCss} >> "$out/gnome-shell-$variant.css"
        done
      '';
in
{
  system.build.gdmTheme = theme;
  fonts.packages = [ pkgs.inter ];

  services.displayManager = {
    gdm.enable = true;
    defaultSession = "niri";
  };

  # This greeter uses its own theme; avoid Stylix replacing Shell's resources.
  stylix.targets.gnome.enable = false;

  # GNOME 50 starts the greeter through this systemd instance. Scope the
  # resource overlay to GDM, keeping it out of normal desktop sessions.
  systemd.user.services."org.gnome.Shell@gdm" = {
    overrideStrategy = "asDropin";
    enableDefaultPath = false;
    serviceConfig.Environment = [
      "G_RESOURCE_OVERLAYS=/org/gnome/shell/theme=${theme}"
    ];
  };

  programs.dconf.profiles.gdm.databases = lib.mkBefore [
    {
      settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          accent-color = "slate";
          clock-format = "24h";
          clock-show-weekday = true;
          font-name = "Inter 11";
          cursor-theme = "Adwaita";
          cursor-size = lib.gvariant.mkInt32 24;
          icon-theme = "Adwaita";
        };
        "org/gnome/desktop/input-sources".sources = [
          (lib.gvariant.mkTuple [
            "xkb"
            "us"
          ])
          (lib.gvariant.mkTuple [
            "xkb"
            "ru"
          ])
        ];
        "org/gnome/login-screen".logo = "";
      };
    }
  ];
}
