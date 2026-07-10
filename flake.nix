{
  description = "System configuration flake.";

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";
    opencode.url = "github:anomalyco/opencode?ref=v1.15.4";
    anirust.url = "github:ctrl-kitty/anirust";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    burpsuitepro = {
      url = "github:xiv3r/Burpsuite-Professional/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent = {
      url = "github:NousResearch/hermes-agent?ref=v2026.6.19";
    };
  };
  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      opencode,
      anirust,
      home-manager,
      nixvim,
      stylix,
      burpsuitepro,
      nixcord,
      sops-nix,
      hermes-agent,
      aagl,
      ...
    }@inputs:
    let
      pkgsConfig = {
        config.allowUnfree = true;
		config.android_sdk.accept_license = true;
        overlays = [
          (final: prev: {
            unstable = import nixpkgs-unstable {
              config.allowUnfree = true;
			  config.android_sdk.accept_license = true;
              system = final.stdenv.hostPlatform.system;
            };
            burpsuitepro = burpsuitepro.packages.${final.stdenv.hostPlatform.system}.default;
            opencode = opencode.packages.${final.stdenv.hostPlatform.system}.default;
            anirust = anirust.packages.${final.stdenv.hostPlatform.system}.default;
            ayugram-desktop = final.symlinkJoin {
              name = "ayugram-desktop-wayland";
              paths = [ prev.ayugram-desktop ];
              buildInputs = [ final.makeWrapper ];
              postBuild = ''
                wrapProgram $out/bin/AyuGram \
                  --set QT_QPA_PLATFORM wayland \
				  --set QT_QPA_PLATFORMTHEME xdgdesktopportal \
                  --set QT_WAYLAND_CLIENT_BUFFER_INTEGRATION linux-dmabuf

                # Disable D-Bus activation so wrapper is actually used
                rm $out/share/applications/com.ayugram.desktop.desktop
                substitute ${prev.ayugram-desktop}/share/applications/com.ayugram.desktop.desktop \
                  $out/share/applications/com.ayugram.desktop.desktop \
                  --replace-fail 'DBusActivatable=true' 'DBusActivatable=false'
              '';
            };
          })
        ];
      };

      mkHost =
        flakeHost: hostModule:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs pkgsConfig flakeHost;
          };
          modules = [
            { nixpkgs = pkgsConfig; }
            ./configuration.nix
            hostModule
            nixvim.nixosModules.nixvim
            home-manager.nixosModules.default
            stylix.nixosModules.stylix
            aagl.nixosModules.default
            sops-nix.nixosModules.sops
            hermes-agent.nixosModules.default
          ];
        };
    in
    {
      nixosConfigurations = {
        laptop = mkHost "laptop" ./hosts/laptop;
        desktop = mkHost "desktop" ./hosts/desktop;
      };
    };
}
