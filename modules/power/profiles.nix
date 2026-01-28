{ lib, pkgs, ... }:

let
  power-profile = pkgs.writeShellApplication {
    name = "power-profile";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gnugrep
      gawk
      util-linux
    ];
    text = ''
      set -euo pipefail

      STATE_DIR="/var/lib/power-profile"
      STATE_FILE="$STATE_DIR/current"

      log() { printf '%s\n' "$*"; }
      warn() { printf 'warning: %s\n' "$*" >&2; }
      die() { printf 'error: %s\n' "$*" >&2; exit 1; }

      need_root() {
        if [ "$(id -u)" != "0" ]; then
          die "run as root (try: sudo power-profile <cmd>)"
        fi
      }

      ensure_state_dir() {
        mkdir -p "$STATE_DIR"
        chmod 0755 "$STATE_DIR" || true
      }

      write_file() {
        # usage: write_file /path value
        local p="$1"
        local v="$2"
        if [ -e "$p" ]; then
          printf '%s' "$v" > "$p" 2>/dev/null || warn "failed to write $p=$v"
        fi
      }

      read_first_line() {
        local p="$1"
        if [ -r "$p" ]; then
          head -n1 "$p" 2>/dev/null || true
        fi
      }

      ac_online() {
        # Returns 0 if on AC, 1 if on battery/unknown
        local ps
        for ps in /sys/class/power_supply/*; do
          [ -d "$ps" ] || continue
          if [ "$(read_first_line "$ps/type")" = "Mains" ]; then
            if [ "$(read_first_line "$ps/online")" = "1" ]; then
              return 0
            fi
          fi
        done
        return 1
      }

      set_cpu_boost() {
        local v="$1" # 0/1
        # Generic cpufreq boost toggle
        if [ -e /sys/devices/system/cpu/cpufreq/boost ]; then
          write_file /sys/devices/system/cpu/cpufreq/boost "$v"
          return 0
        fi
        # AMD pstate can also expose boost under the same path; if not present, ignore.
        return 0
      }

      set_amd_pstate_perf_pct() {
        local min_pct="$1"
        local max_pct="$2"
        local base=/sys/devices/system/cpu/amd_pstate
        if [ -d "$base" ]; then
          write_file "$base/min_perf_pct" "$min_pct"
          write_file "$base/max_perf_pct" "$max_pct"
        fi
      }

      set_policy_knobs() {
        local governor="$1"
        local epp="$2"
        for pol in /sys/devices/system/cpu/cpufreq/policy*; do
          [ -d "$pol" ] || continue
          if [ -n "$governor" ]; then
            write_file "$pol/scaling_governor" "$governor"
          fi
          if [ -n "$epp" ]; then
            write_file "$pol/energy_performance_preference" "$epp"
          fi
        done
      }

      lock_freq_low_if_possible() {
        # Best-effort: if scaling_available_frequencies exists, lock min=max to lowest.
        local locked=0
        for pol in /sys/devices/system/cpu/cpufreq/policy*; do
          [ -d "$pol" ] || continue
          if [ -r "$pol/scaling_available_frequencies" ]; then
            local lowest
            lowest=$(tr ' ' '\n' < "$pol/scaling_available_frequencies" | awk 'NF{print $1}' | sort -n | head -n1 || true)
            if [ -n "$lowest" ]; then
              write_file "$pol/scaling_min_freq" "$lowest"
              write_file "$pol/scaling_max_freq" "$lowest"
              locked=1
            fi
          fi
        done
        if [ "$locked" = "1" ]; then
          return 0
        fi
        return 1
      }

      set_all_cores_online() {
        local cpu
        for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
          [ -d "$cpu" ] || continue
          [ -e "$cpu/online" ] || continue
          write_file "$cpu/online" 1
        done
      }

      set_cores_online_first_n() {
        # Keep cpu0..cpu(n-1) online, offline the rest (if supported).
        local keep="$1"
        local cpu
        for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
          [ -d "$cpu" ] || continue
          local name idx
          name=$(basename "$cpu")
          idx=''${name#cpu}
          [ "$idx" = "0" ] && continue
          [ -e "$cpu/online" ] || continue
          if [ "$idx" -lt "$keep" ]; then
            write_file "$cpu/online" 1
          else
            write_file "$cpu/online" 0
          fi
        done
      }

      set_gpu_runtime_pm() {
        local mode="$1" # auto|on
        local dev
        for dev in /sys/bus/pci/devices/*; do
          [ -d "$dev" ] || continue
          if [ "$(read_first_line "$dev/vendor")" = "0x10de" ]; then
            write_file "$dev/power/control" "$mode"
          fi
        done
      }

      set_amd_dpm_level() {
        local level="$1" # low|auto
        local card
        for card in /sys/class/drm/card[0-9]*; do
          [ -e "$card/device/vendor" ] || continue
          if [ "$(read_first_line "$card/device/vendor")" = "0x1002" ]; then
            if [ -e "$card/device/power_dpm_force_performance_level" ]; then
              write_file "$card/device/power_dpm_force_performance_level" "$level"
            fi
          fi
        done
      }

      record_mode() {
        local mode="$1"
        ensure_state_dir
        printf '%s\n' "$mode" > "$STATE_FILE"
      }

      show_status() {
        local mode
        mode="(unknown)"
        if [ -r "$STATE_FILE" ]; then
          mode=$(read_first_line "$STATE_FILE")
        fi

        if ac_online; then
          log "power: AC"
        else
          log "power: BAT"
        fi
        log "mode: $mode"

        if [ -r /sys/devices/system/cpu/cpufreq/boost ]; then
          log "cpu.boost: $(read_first_line /sys/devices/system/cpu/cpufreq/boost)"
        fi

        if [ -d /sys/devices/system/cpu/amd_pstate ]; then
          log "amd_pstate.epp: $(read_first_line /sys/devices/system/cpu/amd_pstate/energy_performance_preference)"
          log "amd_pstate.min_perf_pct: $(read_first_line /sys/devices/system/cpu/amd_pstate/min_perf_pct)"
          log "amd_pstate.max_perf_pct: $(read_first_line /sys/devices/system/cpu/amd_pstate/max_perf_pct)"
        fi

        if [ -d /sys/devices/system/cpu/cpufreq/policy0 ]; then
          log "cpufreq.governor: $(read_first_line /sys/devices/system/cpu/cpufreq/policy0/scaling_governor)"
          if [ -r /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference ]; then
            log "cpufreq.epp: $(read_first_line /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference)"
          fi
          if [ -r /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq ]; then
            log "cpufreq.min_freq: $(read_first_line /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq)"
            log "cpufreq.max_freq: $(read_first_line /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq)"
          fi
        fi

        # core online count
        local online
        online=0
        local cpu
        for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
          [ -d "$cpu" ] || continue
          if [ -e "$cpu/online" ]; then
            if [ "$(read_first_line "$cpu/online")" = "1" ]; then
              online=$((online + 1))
            fi
          else
            online=$((online + 1))
          fi
        done
        log "cpu.online: $online"

        # Nvidia runtime PM status
        local dev
        for dev in /sys/bus/pci/devices/*; do
          [ -d "$dev" ] || continue
          if [ "$(read_first_line "$dev/vendor")" = "0x10de" ]; then
            local b
            b=$(basename "$dev")
            log "nvidia.$b.power.control: $(read_first_line "$dev/power/control")"
            log "nvidia.$b.power.runtime_status: $(read_first_line "$dev/power/runtime_status")"
          fi
        done
      }

      apply_energy() {
        need_root
        log "applying: energy"
        set_cpu_boost 0
        set_amd_pstate_perf_pct 25 25
        set_policy_knobs "powersave" "power"
        lock_freq_low_if_possible || true
        set_cores_online_first_n 4
        set_gpu_runtime_pm auto
        set_amd_dpm_level low
        record_mode energy
        log "note: for iGPU desktop on Wayland, log out and choose 'Plasma (iGPU)' in SDDM"
      }

      apply_balanced() {
        need_root
        log "applying: balanced"
        set_cpu_boost 0
        set_all_cores_online
        set_amd_pstate_perf_pct 0 100
        set_policy_knobs "powersave" "balance_performance"
        set_gpu_runtime_pm on
        set_amd_dpm_level auto
        record_mode balanced
        log "note: for dGPU desktop on Wayland, log out and choose 'Plasma (dGPU)' in SDDM"
      }

      apply_performance() {
        need_root
        log "applying: performance"
        set_all_cores_online
        set_cpu_boost 1
        set_amd_pstate_perf_pct 0 100
        set_policy_knobs "performance" "performance"
        set_gpu_runtime_pm on
        set_amd_dpm_level auto
        record_mode performance
        log "note: for dGPU desktop on Wayland, log out and choose 'Plasma (dGPU)' in SDDM"
        log "note: AC/BAT auto switching will override performance on next power event"
      }

      apply_auto() {
        need_root
        if ac_online; then
          apply_balanced
        else
          apply_energy
        fi
      }

      usage() {
        cat <<'EOF'
      usage:
        power-profile status
        power-profile auto
        power-profile energy
        power-profile balanced
        power-profile performance
      EOF
      }

      cmd="''${1:-}"
      case "$cmd" in
        status)
          show_status
          ;;
        auto)
          apply_auto
          ;;
        energy)
          apply_energy
          ;;
        balanced)
          apply_balanced
          ;;
        performance)
          apply_performance
          ;;
        ""|-h|--help|help)
          usage
          ;;
        *)
          die "unknown command: $cmd"
          ;;
      esac
    '';
  };

   plasma-wayland-igpu = pkgs.writeShellApplication {
     name = "plasma-wayland-igpu";
     runtimeInputs = with pkgs; [ coreutils gnugrep gawk util-linux ];
     text = ''
       set -euo pipefail

       pick_cards() {
         local intel="" amd="" nvidia=""
         local card
         for card in /sys/class/drm/card[0-9]*; do
           [ -e "$card/device/vendor" ] || continue
           local name
           name=$(basename "$card")
           # Skip connector entries like card0-eDP-1; only accept real /dev/dri/cardN nodes.
           [ -e "/dev/dri/$name" ] || continue
           local v
           v=$(head -n1 "$card/device/vendor" 2>/dev/null || true)
           case "$v" in
             0x8086) intel="/dev/dri/$name" ;;
             0x1002) amd="/dev/dri/$(basename "$card")" ;;
             0x10de) nvidia="/dev/dri/$name" ;;
           esac
         done

         local igpu=""
         if [ -n "$intel" ]; then
           igpu="$intel"
         elif [ -n "$amd" ]; then
           igpu="$amd"
         fi

         if [ -n "$igpu" ] && [ -n "$nvidia" ]; then
           export KWIN_DRM_DEVICES="$igpu:$nvidia"
         elif [ -n "$igpu" ]; then
           export KWIN_DRM_DEVICES="$igpu"
         elif [ -n "$nvidia" ]; then
           export KWIN_DRM_DEVICES="$nvidia"
         fi
       }

       pick_cards
       exec ${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland
     '';
   };

   plasma-wayland-dgpu = pkgs.writeShellApplication {
     name = "plasma-wayland-dgpu";
     runtimeInputs = with pkgs; [ coreutils gnugrep gawk util-linux ];
     text = ''
       set -euo pipefail

       pick_cards() {
         local intel="" amd="" nvidia=""
         local card
         for card in /sys/class/drm/card[0-9]*; do
           [ -e "$card/device/vendor" ] || continue
           local name
           name=$(basename "$card")
           # Skip connector entries like card0-eDP-1; only accept real /dev/dri/cardN nodes.
           [ -e "/dev/dri/$name" ] || continue
           local v
           v=$(head -n1 "$card/device/vendor" 2>/dev/null || true)
           case "$v" in
             0x8086) intel="/dev/dri/$name" ;;
             0x1002) amd="/dev/dri/$(basename "$card")" ;;
             0x10de) nvidia="/dev/dri/$name" ;;
           esac
         done

         local igpu=""
         if [ -n "$intel" ]; then
           igpu="$intel"
         elif [ -n "$amd" ]; then
           igpu="$amd"
         fi

         if [ -n "$igpu" ] && [ -n "$nvidia" ]; then
           export KWIN_DRM_DEVICES="$nvidia:$igpu"
         elif [ -n "$nvidia" ]; then
           export KWIN_DRM_DEVICES="$nvidia"
         elif [ -n "$igpu" ]; then
           export KWIN_DRM_DEVICES="$igpu"
         fi
       }

       pick_cards
       export __GLX_VENDOR_LIBRARY_NAME=nvidia
       exec ${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland
     '';
   };

   plasma-igpu-session = pkgs.writeTextFile {
     name = "plasma-igpu-wayland-session";
     destination = "/share/wayland-sessions/plasma-igpu.desktop";
     text = ''
       [Desktop Entry]
       Name=Plasma (iGPU)
       Comment=Plasma Wayland using iGPU as primary
       Exec=${plasma-wayland-igpu}/bin/plasma-wayland-igpu
       TryExec=${plasma-wayland-igpu}/bin/plasma-wayland-igpu
       Type=Application
       DesktopNames=KDE
     '';
   };

   plasma-dgpu-session = pkgs.writeTextFile {
     name = "plasma-dgpu-wayland-session";
     destination = "/share/wayland-sessions/plasma-dgpu.desktop";
     text = ''
       [Desktop Entry]
       Name=Plasma (dGPU)
       Comment=Plasma Wayland using dGPU as primary
       Exec=${plasma-wayland-dgpu}/bin/plasma-wayland-dgpu
       TryExec=${plasma-wayland-dgpu}/bin/plasma-wayland-dgpu
       Type=Application
       DesktopNames=KDE
     '';
   };

  plasma-gpu-sessions = pkgs.symlinkJoin {
    name = "plasma-gpu-sessions";
    paths = [
      power-profile
      plasma-wayland-igpu
      plasma-wayland-dgpu
      plasma-igpu-session
      plasma-dgpu-session
    ];
    passthru = {
      providedSessions = [ "plasma-igpu" "plasma-dgpu" ];
    };
  };
in
{
  services.tlp.enable = lib.mkForce false;
  services.power-profiles-daemon.enable = lib.mkForce false;

  # Enable runtime power management for Nvidia dGPU.
  hardware.nvidia.powerManagement.enable = lib.mkForce true;
  hardware.nvidia.powerManagement.finegrained = lib.mkForce true;

  environment.systemPackages = [
    power-profile
  ];

  # Provide dedicated SDDM Wayland sessions for choosing iGPU vs dGPU.
  services.displayManager.sessionPackages = [ plasma-gpu-sessions ];

  systemd.services.power-profile-auto = {
    description = "Auto switch power profile (AC/BAT)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${power-profile}/bin/power-profile auto";
    };
    wantedBy = [ "multi-user.target" ];
    after = [ "sysinit.target" "udev.service" ];
  };

  # Trigger profile switching on AC/BAT changes.
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ACTION=="change", TAG+="systemd", ENV{SYSTEMD_WANTS}+="power-profile-auto.service"
  '';
}
