
{ config, pkgs, ... }:
{
  # 1. Симлинк /data -> /var/lib/hermes для 100% совместимости путей (мемори, скрипты, карантин)
  # и привязка downloads к домашней папке
  systemd.tmpfiles.rules = [
    "Z /var/lib/hermes 2770 hermes hermes -"
    "L+ /data - - - - /var/lib/hermes"
    "L+ /var/lib/hermes/downloads - - - - /home/ktvsky/Downloads/hermes"
  ];

  # Пользователь ktvsky получает доступ к группе hermes для запуска CLI
  users.users.ktvsky.extraGroups = [ "hermes" ];

  sops.secrets."hermes-env" = { };

  services.hermes-agent = {
    enable = true;

    # Нативный бэкенд веб-дашборда на порту 9119
    backend = {
      mode = "dashboard";
      host = "127.0.0.1";
      port = 9119;
    };

    addToSystemPackages = true;
    extraDependencyGroups = [ "messaging" "firecrawl" ];

    # Утилиты, доступные агенту в PATH на хосте
    extraPackages = with pkgs; [
      git
      curl
      wget
      jq
      ripgrep
      fd
      python3
      nodejs_22
    ];

    settings = {
      provider = "custom";
      custom_providers = [
        {
          name = "test";
          base_url = "http://127.0.0.1:20128/v1";
        }
      ];
      model = {
        provider = "custom";
        base_url = "http://127.0.0.1:20128/v1";
        default = "agy/gemini-3.8-flash-high";
        supports_vision = true;
      };
      agent = {
        reasoning_effort = "xhigh";
        image_input_mode = "native";
      };
      auxiliary = {
        vision = {
          provider = "custom";
          model = "agy/gemini-3.8-flash-high";
          base_url = "http://127.0.0.1:20128/v1";
        };
        web_extract = {
          provider = "custom";
          model = "agy/gemini-3.8-flash-high";
          base_url = "http://127.0.0.1:20128/v1";
        };
        compression = {
          provider = "custom";
          model = "agy/gemini-3.8-flash-high";
          base_url = "http://127.0.0.1:20128/v1";
        };
        title_generation = {
          provider = "custom";
          model = "agy/gemini-3.8-flash-high";
          base_url = "http://127.0.0.1:20128/v1";
        };
      };
      telegram.proxy = "http://127.0.0.1:2080";
      toolsets = [ "all" ];
      plugins.enabled = [ "omniroute" ];
      image_gen = {
        provider = "omniroute";
        model = "agy/gemini-3.1-flash-image";
      };
    };

    environmentFiles = [
      config.sops.secrets."hermes-env".path
    ];

    environment = {
      TELEGRAM_PROXY = "http://127.0.0.1:2080";
      HERMES_DASHBOARD = "1";
    };
  };
}

