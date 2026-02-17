{ options, pkgs, ... }:

{
  imports = [
    ./classic/nixvim.nix
    ./classic/zsh.nix
    ./classic/gc.nix
    ./emulation/docker.nix
    ./emulation/wine.nix
    #	./graphic/plymouth.nix
    ./graphic/stylix.nix
    #    ./graphic/hyprland.nix
    ./graphic/niri.nix
    ./security/firejail.nix
    ./security/web-pentest.nix
    ./gaming/steam.nix
  ];
  programs.throne = {
    package = pkgs.unstable.throne;
    enable = true;
    tunMode.enable = true;
    tunMode.setuid = true;
  };
  # for uv
  programs.nix-ld = {
    enable = true;
#    libraries =
#      options.programs.nix-ld.libraries.default
#      ++ (with pkgs; [
#        glib # libglib-2.0.so.0
#        libGL
#        stdenv.cc.cc.lib
#        libxkbcommon
#        fontconfig
#        xorg.libX11
#        freetype
#        dbus
#        wayland
#      ]);
  };
  environment.systemPackages = with pkgs; [
    gajim
    nodejs_24
    tree
    tun2proxy
    #    telegram-desktop
    psmisc
    opencode # 4 gb trash??
    anirust
    libreoffice-qt6-fresh # 1.5 gb
    git
    wget
    obsidian
    steam-run
    uv
    mpv
    tor-browser
    ayugram-desktop
    prismlauncher
    kdePackages.ark
    unrar
    p7zip
    sddm-astronaut

    kdePackages.dolphin
    # music player
    kdePackages.elisa
    # paint for me
    pinta
    # unstable.pkgName
    rustup
  ];
}
