{
  description = "System configuration flake.";

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";
    opencode.url = "github:anomalyco/opencode?ref=v1.1.48";
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
  };
  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      opencode,
      home-manager,
      nixvim,
      stylix,
      burpsuitepro,
      nixcord,
      ...
    }@inputs:
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
            ayugram-desktop = final.symlinkJoin {
              name = "ayugram-desktop-overlayed";
              paths = [ prev.ayugram-desktop ];
              buildInputs = [ final.makeWrapper ];
              postBuild = ''
                                			   wrapProgram $out/bin/AyuGram \
                                				  --set QT_QPA_PLATFORM xcb
                								  # Guide kostili https://www.reddit.com/r/hyprland/comments/1pzhnd6/guide_hyprland_telegram_desktop_official_tar/
                                				# Disable D-Bus activation so wrapper is actually used
                                				rm $out/share/applications/com.ayugram.desktop.desktop
                                				substitute ${prev.ayugram-desktop}/share/applications/com.ayugram.desktop.desktop \
                                				  $out/share/applications/com.ayugram.destop.desktop \
                                				  --replace-fail 'DBusActivatable=true' 'DBusActivatable=false'
                                			  '';
            };
          })
        ];
      };

      mkHost = flakeHost: hostModule:
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
