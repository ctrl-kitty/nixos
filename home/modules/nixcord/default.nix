{ ... }:
{
  programs.nixcord = {
    enable = true;
    
	# otherwise got warning to turn on vencord/equicord
	discord.silenceNoModClientWarning = true;
    
	# Do not install basic discord
    #discord.enable = false;
    # equibop.enable = true;
    # vencord.enable = false;
    # equicord.enable = true;
    
	vesktop.enable = true;
    config = {
      frameless = true;

      plugins = {
        volumeBooster.enable = true;
        showHiddenChannels.enable = true;
      };
    };
  };
}
