{ pkgs, ... }:
{
  imports = [
    ./modules/default.nix
    ./home/default.nix
  ];
  home-manager.useGlobalPkgs = true;

  hardware.graphics.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # -5.8s boot time
  systemd.services.NetworkManager-wait-online.enable = false;
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Moscow";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  services.xserver.enable = true;

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

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
      "networkmanager"
      "wheel"
      "adbusers"
      "kvm"
      "docker"
    ];
  };
  # https://github.com/nix-community/stylix/issues/267#issuecomment-2314636091
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    kde-gtk-config
  ];
  programs.firefox.enable = true;
  system.stateVersion = "25.11"; # Did you read the comment?

}
