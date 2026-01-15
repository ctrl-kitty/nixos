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
    vo = "gpu";
    profile = "gpu-hq";
    vd-lavc-dr = "yes";
    
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
