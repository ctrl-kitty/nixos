{ ... }:
{
  programs.nixcord = {
    enable = true;
	# Do not install basic discord
	discord.enable = false;
    equibop.enable = true;
  };
}
