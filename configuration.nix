{ pkgs, ... }:
{
  imports = [
    ./modules/default.nix
    ./home/default.nix
  ];
  home-manager.useGlobalPkgs = true;
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # -5.8s boot time
  systemd.services.NetworkManager-wait-online.enable = false;
  networking.networkmanager.enable = true;
  networking.proxy.httpsProxy = "http://127.0.0.1:2080";
  programs.nh.enable = true;
  programs.nh.flake = "/home/ktvsky/.dotfiles/nixos/";

  time.timeZone = "Europe/Moscow";
  # LOCALES

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocales = [ "ru_RU.UTF-8/UTF-8" ];
  i18n.extraLocaleSettings = {
    LC_ALL = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF8";
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MESSAGES = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
    LC_COLLATE = "en_US.UTF-8";
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    extraPackages = with pkgs; [
      sddm-astronaut
    ];
  };
  #  services.desktopManager.plasma6.enable = true;

  services.xserver.xkb = {
    layout = "us,ru";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.ktvsky = {
    isNormalUser = true;
    description = "ktvsky";
    extraGroups = [
      "input"
      "networkmanager"
      "wheel"
      "adbusers"
      "kvm"
      "docker"
      "gamemode"
    ];
  };

  programs.firefox.enable = true;
  system.stateVersion = "25.11"; # Did you read the comment?
}
