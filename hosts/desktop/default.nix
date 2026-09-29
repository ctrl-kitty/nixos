{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./graphics.nix
    ./services.nix
  ];

  nixpkgs.overlays = lib.mkAfter [
    (_final: prev: {
      unstable = prev.unstable.extend (
        _unstableFinal: unstablePrev: {
          unityhub = unstablePrev.unityhub.overrideAttrs (oldAttrs: {
            postFixup = (oldAttrs.postFixup or "") + ''
              wrapProgram $out/opt/unityhub/unityhub --set GDK_SCALE 2
            '';
          });
        }
      );
    })
  ];

  networking.hostName = lib.mkDefault "DeskNix";

}
