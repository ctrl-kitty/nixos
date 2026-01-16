{ ... }:

{
  virtualisation.docker ={
    enable = true;
	# -1.2s boot time + less resources uses
	enableOnBoot = false;
  };
  systemd.sockets.docker.wantedBy = [ "sockets.target" ];
}
