{ lib, flakeHost, ... }:

lib.mkIf (flakeHost == "desktop") {
  # fix version check due to nixpkgs follows?
  aagl.enableNixpkgsReleaseBranchCheck = false;
  programs.anime-game-launcher.enable = true;

  nix.settings = {
    substituters = [ "https://ezkea.cachix.org" ];
    trusted-public-keys = [ "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI=" ];
  };
}
