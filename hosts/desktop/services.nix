{ pkgs, ... }:
{
  services.ollama.enable = true;
  services.ollama.package = pkgs.ollama-rocm;
  services.open-webui.enable = true;
  environment.systemPackages = [
    pkgs.unstable.llama-cpp
    pkgs.unityhub
  ];
}
