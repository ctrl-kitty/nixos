{ lib, ... }:

{
  # allow 2080 port from docker network, to use proxy
  networking.firewall.extraCommands = ''
    iptables -I nixos-fw 1 -i br+ -p tcp --dport 2080 -j ACCEPT
    iptables -I nixos-fw 1 -i docker0 -p tcp --dport 2080 -j ACCEPT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -i br+ -p tcp --dport 2080 -j ACCEPT || true
    iptables -D nixos-fw -i docker0 -p tcp --dport 2080 -j ACCEPT || true
  '';
  virtualisation.docker = {
    enable = true;
    # -1.2s boot time + less resources uses
    enableOnBoot = false;
  };
  systemd.sockets.docker.wantedBy = [ "sockets.target" ];
}
