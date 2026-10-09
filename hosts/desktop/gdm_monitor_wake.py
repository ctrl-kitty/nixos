"""Recover the desktop's MQ2719-B once when the GDM compositor starts.

Mutter's PowerSaveMode is not equivalent to disabling a CRTC. Reproduce the
tested output off/on cycle instead, using temporary display configurations.
"""

import copy
import json
import signal
import subprocess
import sys
import time


TARGET = ("XYM", "MQ2719-B", "0000000000000")
INTERFACE = "org.gnome.Mutter.DisplayConfig"
OBJECT_PATH = "/org/gnome/Mutter/DisplayConfig"


def unwrap_variant(value):
    if set(value) == {"type", "data"}:
        return value["data"]
    return value


def property_args(properties):
    args = [str(len(properties))]
    for key, (signature, value) in properties.items():
        args.extend([key, signature, str(value).lower()])
    return args


class MutterBus:
    def __init__(self, executable):
        self.executable = executable

    def call(self, method, *args):
        try:
            result = subprocess.run(
                [self.executable, "--user", "--timeout=3s", "--json=short",
                 "call", INTERFACE, OBJECT_PATH, INTERFACE, method, *args],
                check=True, capture_output=True, text=True, timeout=5,
            )
        except (OSError, subprocess.SubprocessError) as error:
            detail = getattr(error, "stderr", None) or str(error)
            raise RuntimeError(f"{method}: {detail.strip()}") from error
        return result.stdout

    def get_state(self):
        return json.loads(self.call("GetCurrentState"), object_hook=unwrap_variant)

    def apply(self, serial, logical, properties):
        # Method 1 is temporary: do not save the disabled layout to monitors.xml.
        args = [str(serial), "1", str(len(logical))]
        for x, y, scale, transform, primary, monitors in logical:
            args.extend(map(str, (x, y, scale, transform)))
            args.extend([str(primary).lower(), str(len(monitors))])
            for connector, mode, monitor_properties in monitors:
                args.extend([connector, mode, *property_args(monitor_properties)])
        args.extend(property_args(properties))
        self.call("ApplyMonitorsConfig", "uua(iiduba(ssa{sv}))a{sv}", *args)


def wake_monitor(bus, *, sleep=time.sleep, target=TARGET):
    serial, monitors, logical, properties = bus.get_state()
    matches = [spec[0] for spec, _, _ in monitors if tuple(spec[1:]) == target]
    if len(matches) != 1:
        return False
    connector = matches[0]
    active = {spec[0] for group in logical for spec in group[5]}
    if connector not in active or len(active) < 2:
        return False

    modes = {}
    for spec, available_modes, monitor_properties in monitors:
        if spec[0] not in active:
            continue
        current = [mode[0] for mode in available_modes if mode[6].get("is-current")]
        if len(current) != 1:
            raise RuntimeError(f"Cannot preserve current mode for {spec[0]}")
        saved = {}
        if "is-underscanning" in monitor_properties:
            saved["underscanning"] = ("b", monitor_properties["is-underscanning"])
        if "color-mode" in monitor_properties:
            saved["color-mode"] = ("u", monitor_properties["color-mode"])
        modes[spec[0]] = [spec[0], current[0], saved]

    original = [group[:5] + [[modes[spec[0]] for spec in group[5]]] for group in logical]
    disabled = copy.deepcopy(original)
    for group in disabled:
        group[5] = [monitor for monitor in group[5] if monitor[0] != connector]
    disabled = [group for group in disabled if group[5]]
    # Mutter requires the remaining layout to start at (0, 0), with a primary.
    min_x = min(group[0] for group in disabled)
    min_y = min(group[1] for group in disabled)
    for group in disabled:
        group[0] -= min_x
        group[1] -= min_y
    if not any(group[4] for group in disabled):
        disabled[0][4] = True
    saved_properties = {}
    if properties.get("supports-changing-layout-mode"):
        saved_properties["layout-mode"] = ("u", properties["layout-mode"])

    print(f"gdm-monitor-wake: cycling {connector} for 3 seconds", flush=True)
    try:
        bus.apply(serial, disabled, saved_properties)
        sleep(3)
    finally:
        # Restore even if the disable call timed out after applying, or a signal
        # interrupted the wait. Hotplug can change the serial during the cycle.
        for attempt in range(5):
            try:
                bus.apply(bus.get_state()[0], original, saved_properties)
                break
            except RuntimeError:
                if attempt == 4:
                    raise
                sleep(0.2)
    print(f"gdm-monitor-wake: restored {connector}", flush=True)
    return True


def interrupted(signum, _frame):
    # Give the finally block a chance to restore the output before exiting.
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    raise SystemExit(128 + signum)


def main():
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    bus = MutterBus(sys.argv[1])
    try:
        for attempt in range(10):
            try:
                bus.get_state()
                break
            except RuntimeError:
                if attempt == 9:
                    raise
                time.sleep(0.5)
        if not wake_monitor(bus):
            print("gdm-monitor-wake: target or active peer absent; skipped", flush=True)
    except (RuntimeError, ValueError, KeyError) as error:
        print(f"gdm-monitor-wake: {error}", file=sys.stderr, flush=True)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
