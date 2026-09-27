{ pkgs, ... }:
{
  # GDM runs a separate Mutter compositor and does not read Niri's outputs.
  # Keep this file scoped to its greeter, including GNOME 50's transient users.
  systemd.user.services."org.gnome.Shell@gdm".serviceConfig.Environment = [
    "XDG_CONFIG_DIRS=/etc/xdg/gdm:/etc/xdg"
  ];
  # GNOME 50 supports fractional scaling without the retired experimental flag.
  environment.etc."xdg/gdm/monitors.xml".text = ''
    <monitors version="2">
      <policy>
        <stores><store>system</store></stores>
      </policy>
      <configuration>
        <layoutmode>logical</layoutmode>
        <logicalmonitor>
          <x>1920</x>
          <y>0</y>
          <scale>1.5</scale>
          <primary>yes</primary>
          <monitor>
            <monitorspec>
              <connector>DP-1</connector>
              <vendor>XYM</vendor>
              <product>MQ2719-B</product>
              <serial>0000000000000</serial>
            </monitorspec>
            <mode>
              <width>3840</width>
              <height>2160</height>
              <rate>100</rate>
            </mode>
          </monitor>
        </logicalmonitor>
        <logicalmonitor>
          <x>0</x>
          <y>360</y>
          <scale>1</scale>
          <monitor>
            <monitorspec>
              <connector>HDMI-A-1</connector>
              <vendor>PHL</vendor>
              <product>PHL 243V7</product>
              <serial>0x00001ae7</serial>
            </monitorspec>
            <mode>
              <width>1920</width>
              <height>1080</height>
              <rate>60</rate>
            </mode>
          </monitor>
        </logicalmonitor>
      </configuration>
    </monitors>
  '';

  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.amdgpu.opencl.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    libva
    libva-utils
    libva-vdpau-driver
    libvdpau-va-gl
  ];
  hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [
    libva-vdpau-driver
    libvdpau-va-gl
  ];

  environment.sessionVariables = {
    VDPAU_DRIVER = "radeonsi";
    LIBVA_DRIVER_NAME = "radeonsi";
  };
  # some fps boost, but I don't want to make it possibly unstable
  # hardware.graphics.package = pkgs.unstable.mesa;
}
