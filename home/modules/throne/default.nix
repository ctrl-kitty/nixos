{ ... }:
{
  xdg.configFile."Throne/config/route_profiles/999.json" = {
    source = ./rules.json;
    force = true;
  };
  xdg.configFile."Throne/config/route_profiles/Nix" = {
    source = ./Nix;
    force = true;
  };
}
