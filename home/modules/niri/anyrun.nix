{ pkgs, ... }:
{
  programs.anyrun = {
    enable = true;
    config = {
      x = {
        fraction = 0.5;
      };
      y = {
        fraction = 0.3;
      };
      width = {
        fraction = 0.3;
      };
      # buggy, fixed here https://github.com/anyrun-org/anyrun/pull/240/changes/ddfe7f292ae493eeb0d2ed4a9b7e504486f6aee6
      # just'll wait for 26.05
      # closeOnClick = true;
      plugins = [
        "${pkgs.anyrun}/lib/libapplications.so"
        "${pkgs.anyrun}/lib/librink.so"
        "${pkgs.anyrun}/lib/libwebsearch.so"
        # don't respect maxEntries
        "${pkgs.anyrun}/lib/libnix_run.so"
      ];
    };
    extraCss = /* css */ ''
      window {
        border-radius: 24px;
        padding: 14px;
      }

      .main {
        border-radius: 20px;
        padding: 4px;
      }

      text {
        min-height: 30px;
        border-radius: 999px;
        padding: 0 14px;
        margin: 0 0 10px 0;
      }

      .matches {
        margin: 0;
        padding: 0;
      }

      .plugin {
        margin: 0 0 4px 0;
        padding: 0;
      }

      .plugin:last-child {
        margin-bottom: 0;
      }

      .plugin .info {
        margin-bottom: 4px;
        padding: 0 4px;
      }

      .plugin .info image {
        margin-right: 8px;
      }

      .plugin .info label {
        font-weight: 600;
      }

      .match {
        border-radius: 14px;
        padding: 4px 8px;
        margin: 2px 0;
      }

      .match image {
        margin-right: 10px;
      }

      .match .title {
        font-weight: 600;
        margin-bottom: 1px;
      }

      .match .description {
        font-size: 0.92em;
      }
    '';
  };
}
