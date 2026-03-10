
{ config, pkgs, lib, ... }:

let
  blissOsIso = pkgs.fetchurl {
    url = "mirror://sourceforge/blissos-x86/Official/BlissOS16/Gapps/Generic/Bliss-v16.9.7-x86_64-OFFICIAL-gapps-20241011.iso";
    hash = "sha256-FxN3EftCI2ZArG/kQh/LO9FXEAZfz3XCCAfAGPQuN1E="; # fill in after prefetch
  };

  androidVm = pkgs.writeShellScriptBin "android" ''
    set -e

    VM_DIR="$HOME/.local/share/blissos-gapps"
    DISK_FILE="$VM_DIR/main_disk.qcow2"

    mkdir -p "$VM_DIR"

    if [ ! -f "$DISK_FILE" ]; then
      echo "Creating 16GB virtual disk for Android..."
      ${pkgs.qemu_kvm}/bin/qemu-img create -f qcow2 "$DISK_FILE" 16G
    fi

    exec ${pkgs.qemu_kvm}/bin/qemu-system-x86_64 \
      -enable-kvm \
      -m 4096 \
      -smp 4 \
      -cpu host \
      -machine q35 \
      -vga virtio \
      -display sdl,gl=on \
      -device qemu-xhci,id=xhci \
      -device usb-mouse,bus=xhci.0 \
      -device usb-kbd,bus=xhci.0 \
      -audiodev pa,id=snd0 \
      -device intel-hda -device hda-output,audiodev=snd0 \
      -netdev user,id=net0,hostfwd=tcp::5555-:5555 \
      -device virtio-net-pci,netdev=net0 \
      -drive file="$DISK_FILE",format=qcow2,if=virtio \
      -cdrom ${blissOsIso} \
      -boot menu=on
  '';
in
{
  options.programs.androidVm = {
    enable = lib.mkEnableOption "BlissOS Android 13 QEMU VM";
  };

  config = lib.mkIf config.programs.androidVm.enable {
    environment.systemPackages = [ androidVm ];

    # KVM access for the current user
    users.groups.kvm = {};
    boot.kernelModules = [ "kvm-intel" "kvm-amd" ];
  };
}
