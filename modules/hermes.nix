
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
	  uv
      nodejs_22
    ];

    settings = {
      provider = "custom:a6api";
      custom_providers = [
        {
          name = "custom";
          base_url = "http://127.0.0.1:20128/v1";
		  key_env = "OPENAI_API_KEY";
        }
        # OpenAI-совместимый шлюз; ключ: A6API_KEY в hermes-env (sops)
        {
          name = "a6api";
          base_url = "https://api.a6api.vip/v1";
          key_env = "A6API_KEY";
        }
      ];
      model = {
        provider = "custom:a6api";
        base_url = "https://api.a6api.vip/v1";
        default = "claude-opus-5-5";
        supports_vision = true;
      };
      agent = {
        reasoning_effort = "medium";
        image_input_mode = "auto";
      };
      auxiliary = {
        vision = {
          provider = "custom:a6api";
          model = "claude-opus-5-5";
          base_url = "https://api.a6api.vip/v1";
        };
        web_extract = {
          provider = "custom:a6api";
          model = "claude-opus-5-5";
          base_url = "https://api.a6api.vip/v1";
        };
        compression = {
          provider = "custom:a6api";
          model = "claude-opus-5-5";
          base_url = "https://api.a6api.vip/v1";
        };
        title_generation = {
          provider = "custom:a6api";
          model = "claude-opus-5-5";
          base_url = "https://api.a6api.vip/v1";
        };
      };
      telegram.proxy = "http://127.0.0.1:2080";
      toolsets = [ "all" ];
	  mcp_servers = {
        blender = {
          command = "uvx";
          args = [ "mcp-for-blender" ];
        };
      };
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

