{
  description = "System configuration flake.";

  inputs = {
	nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";
    opencode.url = "github:anomalyco/opencode?ref=dev";
#    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
	burpsuitepro = {
	  url = "github:xiv3r/Burpsuite-Professional/main";
	  inputs.nixpkgs.follows = "nixpkgs";
	};
  };
  outputs = { nixpkgs, nixpkgs-unstable, opencode, home-manager, nixvim, burpsuitepro, ... }@inputs:
  let
    pkgsConfig = {
      config.allowUnfree = true;
      overlays = [
        (final: prev: {
          unstable = import nixpkgs-unstable {
            config.allowUnfree = true;
			system = final.stdenv.hostPlatform.system;
          };
		  burpsuitepro = burpsuitepro.packages.${final.stdenv.hostPlatform.system}.default;
		  opencode = opencode.packages.${final.stdenv.hostPlatform.system}.default;
		  telegram-desktop = final.symlinkJoin {
			  name = "telegram-desktop";
			  paths = [ prev.telegram-desktop ];
			  buildInputs = [ final.makeWrapper ];
			  postBuild = ''
			   wrapProgram $out/bin/Telegram \
				  --set QT_QPA_PLATFORM xcb
				# Guide kostili https://www.reddit.com/r/hyprland/comments/1pzhnd6/guide_hyprland_telegram_desktop_official_tar/
				# Disable D-Bus activation so wrapper is actually used
				rm $out/share/applications/org.telegram.desktop.desktop
				substitute ${prev.telegram-desktop}/share/applications/org.telegram.desktop.desktop \
				  $out/share/applications/org.telegram.desktop.desktop \
				  --replace-fail 'DBusActivatable=true' 'DBusActivatable=false'
			  '';
		  };
		})
      ];
    };
  in
  {
    nixosConfigurations = {
      RedNixOs = nixpkgs.lib.nixosSystem {
		specialArgs = { inherit inputs home-manager nixvim; };
        modules = [
          ./configuration.nix
#	      nixos-hardware.nixosModules.asus-fa507nv
          nixvim.nixosModules.nixvim
          { nixpkgs = pkgsConfig; }
		];
      };
    };
  };
}
