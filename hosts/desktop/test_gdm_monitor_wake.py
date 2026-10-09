import copy
import unittest

from gdm_monitor_wake import wake_monitor


TARGET = ["DP-2", "XYM", "MQ2719-B", "0000000000000"]
PEER = ["HDMI-A-2", "PHL", "PHL 243V7", "0x00001ae7"]


def fixture():
    return [
        10,
        [
            [TARGET, [["4k100", 3840, 2160, 100.0, 1.5, [1.0, 1.5], {"is-current": True}]], {}],
            [PEER, [["1080p60", 1920, 1080, 60.0, 1.0, [1.0], {"is-current": True}]], {}],
        ],
        [[1920, 0, 1.5, 0, True, [TARGET], {}], [0, 360, 1.0, 0, False, [PEER], {}]],
        {"layout-mode": 1, "supports-changing-layout-mode": True},
    ]


class FakeBus:
    def __init__(self, state=None):
        self.state = copy.deepcopy(state or fixture())
        self.calls = []
        self.fail_restore = 0

    def get_state(self):
        return copy.deepcopy(self.state)

    def apply(self, serial, logical, properties):
        if serial != self.state[0]:
            raise RuntimeError("stale display serial")
        if self.calls and self.fail_restore:
            self.fail_restore -= 1
            raise RuntimeError("monitor reconnecting")
        self.calls.append(copy.deepcopy((logical, properties)))
        self.state[0] += 1


class WakeTests(unittest.TestCase):
    def test_only_target_is_disabled_then_original_layout_is_restored(self):
        bus = FakeBus()
        sleeps = []
        self.assertTrue(wake_monitor(bus, sleep=sleeps.append))
        disabled, restored = [call[0] for call in bus.calls]
        self.assertEqual(disabled, [[0, 0, 1.0, 0, True, [["HDMI-A-2", "1080p60", {}]]]])
        self.assertEqual(restored, [
            [1920, 0, 1.5, 0, True, [["DP-2", "4k100", {}]]],
            [0, 360, 1.0, 0, False, [["HDMI-A-2", "1080p60", {}]]],
        ])
        self.assertEqual(sleeps, [3])
        self.assertEqual(bus.calls[-1][1], {"layout-mode": ("u", 1)})

    def test_restores_if_interrupted_while_output_is_disabled(self):
        bus = FakeBus()

        def interrupt(_):
            raise KeyboardInterrupt

        with self.assertRaises(KeyboardInterrupt):
            wake_monitor(bus, sleep=interrupt)
        self.assertEqual(len(bus.calls), 2)
        self.assertEqual(bus.calls[-1][0][0][5][0][0], "DP-2")

    def test_restoration_refreshes_serial_and_retries_hotplug_race(self):
        bus = FakeBus()

        def hotplug(_):
            bus.state[0] += 1
            if _ == 3:
                bus.fail_restore = 1

        self.assertTrue(wake_monitor(bus, sleep=hotplug))
        self.assertEqual(len(bus.calls), 2)

    def test_preserves_supported_underscan_and_color_settings(self):
        state = fixture()
        state[1][1][2] = {"is-underscanning": True, "color-mode": 0}
        bus = FakeBus(state)
        wake_monitor(bus, sleep=lambda _: None)
        for logical, _ in bus.calls:
            peer = next(monitor for group in logical for monitor in group[5]
                        if monitor[0] == "HDMI-A-2")
            self.assertEqual(peer[2], {"underscanning": ("b", True), "color-mode": ("u", 0)})

    def test_attempts_restoration_when_disable_reply_is_lost(self):
        class LostReplyBus(FakeBus):
            def apply(self, *args):
                super().apply(*args)
                if len(self.calls) == 1:
                    raise RuntimeError("disable reply timed out")

        bus = LostReplyBus()
        with self.assertRaisesRegex(RuntimeError, "disable reply timed out"):
            wake_monitor(bus, sleep=lambda _: None)
        self.assertEqual(len(bus.calls), 2)
        self.assertEqual(bus.calls[-1][0][0][5][0][0], "DP-2")

    def test_restoration_failure_has_bounded_retries(self):
        bus = FakeBus()

        def disconnected(seconds):
            if seconds == 3:
                bus.fail_restore = 100

        with self.assertRaisesRegex(RuntimeError, "monitor reconnecting"):
            wake_monitor(bus, sleep=disconnected)
        self.assertEqual(bus.fail_restore, 95)

    def test_follows_monitor_identity_after_a_connector_change(self):
        state = copy.deepcopy(fixture())
        state[1][0][0][0] = "DP-4"
        bus = FakeBus(state)
        self.assertTrue(wake_monitor(bus, sleep=lambda _: None))
        self.assertEqual(bus.calls[-1][0][0][5][0][0], "DP-4")

    def test_skips_other_monitor_or_no_active_peer(self):
        for change in ("other-monitor", "no-peer", "disabled-target"):
            with self.subTest(change=change):
                state = fixture()
                if change == "other-monitor":
                    state[1][0][0] = ["DP-2", "OTHER", "Other model", "123"]
                elif change == "no-peer":
                    state[2] = state[2][:1]
                else:
                    state[2] = state[2][1:]
                bus = FakeBus(state)
                self.assertFalse(wake_monitor(bus, sleep=lambda _: None))
                self.assertEqual(bus.calls, [])


if __name__ == "__main__":
    unittest.main()
