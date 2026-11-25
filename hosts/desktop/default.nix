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

  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-uuid/92233d36-8d5a-40dc-8ae6-7dd927c73a4f";
    fsType = "ext4";
    options = [
      "nofail"
      # Avoid background inode-table writes on this drive with failing SMART indicators.
      "noinit_itable"
    ];
  };

  environment.etc."udisks2/ST8000NM0055-1RM112-ZA1C0CXX.conf".text = ''
    [ATA]
    StandbyTimeout=240
  '';

}
