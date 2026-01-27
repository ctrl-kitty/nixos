{ ... }:
{
programs.mpv = {  
  config = {
    # General
    border = "no";
    speed = 2.0;
    save-position-on-quit = true;
    keep-open = "always";
    
    # VIDEO
	hwdec = "fast";
    vo = "gpu";
	gpu-context = "wayland";
    profile = "fast";
    vd-lavc-dr = "yes";
	hwdec-codecs = "all";
    
    # AUDIO
    af-add = "scaletempo2";
    alang = "ru";
    audio-file-auto = "fuzzy";
    
    # SUBS
    slang = "ru,en";
    sub-auto = "fuzzy";
    sub-file-paths = "RUS/**:Subs:RUS Subs/**:Rus Subs/**:Rus/**:Rus subs/**:ENG Subs/**";
  };
  
  profiles = {
    "extension.gif" = {
      loop-file = "inf";
      interpolation = "no";
    };
  };
};
}
