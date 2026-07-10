{ config, pkgs, ... }:
{
  systemd.tmpfiles.rules = [
    "Z /var/lib/hermes 2750 hermes hermes -"
  ];

  systemd.services.hermes-dashboard = {
    wantedBy = [ "multi-user.target" ];
    after = [ "hermes-agent.service" ];
    requires = [ "hermes-agent.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.docker}/bin/docker exec hermes-agent /data/current-package/bin/hermes dashboard --no-open --skip-build";
      Restart = "always";
      RestartSec = 10;
    };
  };

  sops.secrets."hermes-env" = { };

  services.hermes-agent = {
    enable = true;
    container = {
      enable = true;
      hostUsers = [ "ktvsky" ];
      extraVolumes = [
        "/home/ktvsky/Downloads/hermes:/data/downloads:rw"
      ];
      extraOptions = [
        "--add-host=host.docker.internal:host-gateway"
        "--env=HERMES_DASHBOARD=1"
      ];
    };
    addToSystemPackages = true;
    extraDependencyGroups = [ "messaging" "firecrawl" ];

    settings = {
      model.base_url = "http://host.docker.internal:20128/v1";
      model.default = "test";
      telegram.proxy = "http://host.docker.internal:2080";
      toolsets = [ "all" ];
    };

    environmentFiles = [
      config.sops.secrets."hermes-env".path
    ];

    environment = {
      TELEGRAM_PROXY = "http://host.docker.internal:2080";
#	  HTTPS_PROXY = "http://host.docker.internal:2080";
# broking omniroute connect idk why
      HERMES_DASHBOARD = "1";
    };
  };
}
