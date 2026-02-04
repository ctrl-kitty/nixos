{ ... }:
{
  programs.nixcord = {
    enable = true;
    #    discord.vencord.enable = true;
	# wayland normal support
    vesktop.enable = true;
  };
}
