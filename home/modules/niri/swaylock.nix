{ ... }:
{
  programs.swaylock = {
    enable = true;
    settings = {
      daemonize = true;
      show-keyboard-layout = true;
      indicator-caps-lock = true;
    };
  };
}
