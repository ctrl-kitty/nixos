{ ... }:
{
  # No disk swap on this machine; compressed RAM swap avoids hard freezes when memory fills up.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Kill the biggest offender before the system thrashes into a lockup.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    enableNotifications = true;
  };

  # Alt+SysRq+F = manual OOM kill, Alt+SysRq+REISUB = safe reboot when frozen.
  boot.kernel.sysctl."kernel.sysrq" = 1;
}
