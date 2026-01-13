{pkgs, ...}:

{
  imports = [
	./classic/nixvim.nix
	./classic/zsh.nix
	./classic/gc.nix
	./emulation/docker.nix
	./emulation/wine.nix
#	./graphic/plymouth.nix
	./security/firejail.nix
	./security/web-pentest.nix
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
    tree
    tun2proxy
    telegram-desktop
    psmisc
    opencode # 4 gb trash??
    libreoffice-qt6-fresh #1.5 gb
    git
    discord
    wget
    obsidian
    steam-run
    uv
	mpv
    # unstable.pkgName
  ];
}
