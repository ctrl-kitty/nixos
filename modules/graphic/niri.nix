{ pkgs, ... }:
{
  # Pin the merged Steam/Unity popup-focus fix until it reaches a release.
  # https://github.com/Supreeeme/xwayland-satellite/pull/494
  nixpkgs.overlays = [
    (final: prev: {
      xwayland-satellite = prev.xwayland-satellite.overrideAttrs (old: rec {
        version = "0.8.2-unstable-2026-09-09";
        src = final.fetchFromGitHub {
          owner = "Supreeeme";
          repo = "xwayland-satellite";
          rev = "add2795134593faafce60e404a0a75df68e9ee0c";
          hash = "sha256-0TxfMgqW0/BLD4M942c5DCKYrtPvzsPJwvdcco4LQUM=";
        };
        cargoDeps = final.rustPlatform.fetchCargoVendor {
          inherit (old) pname;
          inherit version src;
          hash = "sha256-s1gl9eR6Mt2QLrhfcowstPFjzwE/lz4PJhJzWYHoIHg=";
        };
        # The popup regression tests use a mock compositor; only the separate
        # integration suite requires a running display server.
        doCheck = true;
        cargoTestFlags = [ "--lib" ];
        meta = old.meta // {
          changelog = "https://github.com/Supreeeme/xwayland-satellite/compare/v0.8.2...${src.rev}";
        };
      });
    })
  ];

  environment.systemPackages = with pkgs; [
    xwayland-satellite
    # D-Bus activation and remote-file support for Dolphin outside Plasma.
    kdePackages.kio
    kdePackages.kio-fuse
    kdePackages.kio-extras
  ];

  # KService needs an application menu for Dolphin's "Open With" dialog.
  # A standard XDG menu keeps this independent of the Plasma desktop.
  environment.etc."xdg/menus/applications.menu".text = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
      "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <DefaultMergeDirs/>
      <Include><All/></Include>
    </Menu>
  '';
  programs.niri.enable = true;

  xdg.portal = {
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };
}
