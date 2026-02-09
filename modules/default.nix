{ inputs, pkgs, ... }:

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
  programs.nix-ld.enable = true;
  environment.systemPackages = with pkgs; [
    nodejs_24
    tree
    tun2proxy
    #    telegram-desktop
    psmisc
    opencode # 4 gb trash??
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
	sddm-astronaut
	# music player
    kdePackages.elisa
    # unstable.pkgName
  ];
}
