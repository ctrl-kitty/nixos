{ ... }:
{
  # force = true: Throne rewrites these at runtime; nix config is the source of truth
  xdg.configFile."Throne/config/route_profiles/123.json" = {
    source = ./rules.json;
    force = true;
  };
  xdg.configFile."Throne/config/route_profiles/Nix" = {
    source = ./Nix;
    force = true;
  };
  xdg.configFile."Throne/config/configs.json" = {
    source = ./configs.json;
    force = true;
  };
}
