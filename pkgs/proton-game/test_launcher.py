"""Regression checks for filtering and the launch boundary; never start a game."""

from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


source = Path(os.environ.get("PROTON_GAME_SOURCE", Path(__file__).with_name("launcher.py")))
spec = importlib.util.spec_from_file_location("launcher", source)
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.root = self.base / "Game with spaces"
        self.root.mkdir()
        self.old_cwd = Path.cwd()
        self.addCleanup(os.chdir, self.old_cwd)
        os.chdir(self.root)
        self.steam = self.base / "Steam"
        self.library = self.base / 'Library "quoted" \\ 日本語'
        self.put(self.steam / "steamapps/libraryfolders.vdf",
                 '"libraryfolders" { "0" { "path" "' +
                 str(self.library).replace("\\", "\\\\").replace('"', '\\"') + '" } }')
        self.proton = self.library / "steamapps/common/Proton - Experimental/proton"
        self.put(self.proton, executable=True)
        self.put(self.proton.parent / "toolmanifest.vdf", '"require_tool_appid" "4183110"')
        self.runtime = self.steam / "steamapps/common/SteamLinuxRuntime_4"
        self.put(self.runtime / "_v2-entry-point", executable=True)
        self.put(self.steam / "steamapps/appmanifest_4183110.acf", '"installdir" "SteamLinuxRuntime_4"')
        self.env = {"STEAM_DIR": str(self.steam), "XDG_DATA_HOME": str(self.base / "data")}

    def put(self, path, content="", executable=False):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        if executable:
            path.chmod(0o755)
        return path

    def invoke(self, *args):
        output = io.StringIO()
        with patch.dict(os.environ, self.env, clear=True), redirect_stdout(output):
            launcher.main(list(args))
        return output.getvalue()

    def launch(self, *args):
        with patch.object(launcher.shutil, "which", return_value="/bin/steam-run"), \
             patch.object(launcher.os, "execvpe", side_effect=SystemExit(37)) as execute:
            with self.assertRaises(SystemExit) as result:
                self.invoke(*args)
        self.assertEqual(result.exception.code, 37)
        return Path(execute.call_args.args[2]["STEAM_COMPAT_DATA_PATH"])

    def test_filter_helpers_without_hiding_game_launchers(self):
        games = ["Crash Bandicoot.exe", "Launcher.EXE", "start_protected_game.exe", "Retail/Game.exe"]
        helpers = ["UnityCrashHandler64.exe", "CrashReportClient-Win64-Shipping.exe",
                   "unins000.exe", "VC_redist.x64.EXE", "EasyAntiCheat_EOS_Setup.exe",
                   "_CommonRedist/DirectX/DXSETUP.exe", "_original files/Game.exe"]
        for name in games + helpers:
            self.put(self.root / name)
        self.assertCountEqual(launcher.executables(self.root), games)
        self.assertCountEqual(launcher.executables(self.root, True), games + helpers)

    def test_all_still_excludes_prefixes_and_directory_symlinks(self):
        self.put(self.root / "Game.exe")
        for name in [".proton/pfx/drive_c/windows/notepad.exe", ".wine/drive_c/windows/cmd.exe",
                     "custom-prefix/drive_c/windows/regedit.exe", ".git/hidden.exe"]:
            self.put(self.root / name)
        self.put(self.root / "custom-prefix/system.reg")
        external = self.put(self.base / "outside/External.exe")
        (self.root / "linked-folder").symlink_to(external.parent, target_is_directory=True)
        (self.root / "linked.exe").symlink_to(external)
        self.assertEqual(launcher.executables(self.root, True), ["Game.exe"])

    def test_steam_libraries_and_runtime_dependency(self):
        steam, libraries = launcher.steam_installation(self.env)
        self.assertEqual(steam, self.steam)
        self.assertIn(self.library, libraries)
        proton = launcher.proton_installation(libraries, None)
        self.assertEqual(proton, self.proton)
        self.assertEqual(launcher.runtime_installation(proton, libraries, None), self.runtime)
        (self.runtime / "_v2-entry-point").unlink()
        with self.assertRaisesRegex(launcher.LaunchError, "4183110"):
            launcher.runtime_installation(proton, libraries, None)

    def test_explicit_proton_and_runtime_overrides(self):
        proton = self.put(self.base / "GE-Proton/proton", executable=True)
        self.assertEqual(launcher.proton_installation([], str(proton.parent)), proton)
        self.assertEqual(launcher.runtime_installation(proton, [], str(self.runtime)), self.runtime)
        with self.assertRaisesRegex(launcher.LaunchError, "Not a Proton"):
            launcher.proton_installation([], str(self.base / "missing"))

    def test_dry_run_does_not_create_prefix_and_preserves_options(self):
        game = self.put(self.root / "Retail/Игра $(false).EXE")
        self.env.update(PROTON_ENABLE_WAYLAND="0", PROTON_ENABLE_HDR="1")
        output = self.invoke("--exe", str(game), "--dry-run", "--log", "--appid", "123", "--", "-windowed", "a b")
        self.assertIn("STEAM_COMPAT_APP_ID=123", output)
        self.assertIn("PROTON_ENABLE_WAYLAND=0", output)
        self.assertIn("PROTON_ENABLE_HDR=1", output)
        self.assertIn("PROTON_LOG=1", output)
        self.assertIn("-windowed 'a b'", output)
        self.assertFalse((self.root / ".proton").exists())
        self.assertFalse((self.base / "data").exists())

    def test_launch_passes_exact_arguments_and_uses_executable_directory(self):
        game = self.put(self.root / "Retail/Game 'quoted'.exe")
        args = ["-windowed", "a b", "$(touch should-not-exist)"]
        # Stop at exec; inspect the actual process arguments, environment and cwd.
        with patch.object(launcher.shutil, "which", return_value="/bin/steam-run"), \
             patch.object(launcher.os, "execvpe", side_effect=SystemExit(37)) as execute:
            with self.assertRaises(SystemExit) as result:
                self.invoke("--exe", str(game), "--", *args)
        self.assertEqual(result.exception.code, 37)
        command = execute.call_args.args[1]
        env = execute.call_args.args[2]
        self.assertEqual(command, ["steam-run", str(self.runtime / "_v2-entry-point"),
                                  "--verb=waitforexitandrun", "--", str(self.proton),
                                  "waitforexitandrun", str(game), *args])
        self.assertEqual(Path.cwd(), game.parent)
        prefix = Path(env["STEAM_COMPAT_DATA_PATH"])
        self.assertEqual(prefix.parent, self.base / "data/proton-game/prefixes")
        self.assertTrue(prefix.is_dir())
        self.assertEqual(launcher.prefix_history(self.env)[0]["prefix"], str(prefix))
        self.assertFalse((game.parent / "should-not-exist").exists())

    def test_chooser_uses_null_delimiters_and_cancellation_is_clean(self):
        name = "Game\nwith newline.exe"
        self.put(self.root / name)
        with patch.object(launcher.sys.stdin, "isatty", return_value=True), \
             patch.object(launcher.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess([], 0, os.fsencode(name) + b"\0")
            with patch.dict(os.environ, {"FZF_DEFAULT_OPTS": "--print-query"}):
                self.assertEqual(launcher.choose([name]), name)
            self.assertEqual(run.call_args.kwargs["input"], os.fsencode(name) + b"\0")
            self.assertNotIn("FZF_DEFAULT_OPTS", run.call_args.kwargs["env"])
            run.return_value = subprocess.CompletedProcess([], 130, b"")
            with self.assertRaises(SystemExit) as result:
                self.invoke()
            self.assertEqual(result.exception.code, 130)
        self.assertFalse((self.root / ".proton").exists())
        self.assertFalse((self.base / "data").exists())

    def test_version_families_and_title_numbers(self):
        versions = [
            "My Game_v1", "My.Game-v2", "MY_GAME_v.1.2.3", "My Game version 1.2",
            "My Game Version: 2.1", "My Game ver.1.2.3.4", "My Game [v1.2.3]",
            "My Game (1.2.3)", "My Game_1_2_3", "My Game 1.2a", "My Game v1.0-beta.2",
            "My Game v1.0-rc1+build.7", "My Game Build 12345", "My Game_b12345",
            "My Game Revision 52", "My Game_r52", "My Game Patch 1", "My Game Update 7",
            "My Game 2026-10-05", "My Game_2026.10.05", "My Game_20261005",
            "My Game v1.2 Build 567", "My Game v1.2-GOG", "My.Game.v1.2-FitGirl.Repack",
            "My Game [v1.2] (DODI Repack)", "My Game v1.2 Portable",
        ]
        for title in versions:
            with self.subTest(title=title):
                self.assertEqual(launcher.game_key(title), "my game")
        for title in ["Portal 2", "Cyberpunk 2077", "Doom 64", "F1 2024", "007 First Light"]:
            with self.subTest(title=title):
                self.assertEqual(launcher.game_key(title + "_v1.2"), launcher.game_key(title))
        self.assertNotEqual(launcher.game_key("Game 1_v2"), launcher.game_key("Game 2_v2"))
        self.assertEqual(launcher.game_key("Игра_версия"), "игра версия")
        self.assertEqual(launcher.game_key("Cafe\u0301 v1"), launcher.game_key("Café v2"))
        self.assertEqual(launcher.game_key("Game Steam"), "game steam")

    def test_upgrade_offers_shared_prefix_and_remembers_choice_after_old_folder_deleted(self):
        first = self.base / "My.Game_v1.2.3"
        self.put(first / "Game.exe")
        os.chdir(first)
        prefix = self.launch("--exe", "Game.exe")
        save = self.put(prefix / "pfx/drive_c/users/steamuser/save.dat", "progress")
        # Simulate deleting the previous game installation, keeping shared data.
        (first / "Game.exe").unlink()
        first.rmdir()
        second = self.base / "My Game [v2.0]"
        self.put(second / "Game.exe")
        os.chdir(second)
        with patch.object(launcher.sys.stdin, "isatty", return_value=True), \
             patch.object(launcher, "choose", side_effect=lambda choices, **kw: choices[0]) as chooser:
            self.assertEqual(self.launch("--exe", "Game.exe"), prefix)
        self.assertIn("Same game:", chooser.call_args.args[0][0])
        self.assertEqual(save.read_text(), "progress")
        with patch.object(launcher, "choose", side_effect=AssertionError("choice should be remembered")):
            self.assertEqual(self.launch("--exe", "Game.exe"), prefix)
        self.assertFalse((second / ".proton").exists())

    def test_legacy_prefix_discovery_and_sequel_ranking(self):
        old = self.base / "Game 2 Build 100"
        legacy = old / ".proton"
        self.put(legacy / "pfx/drive_c/save.dat", "keep")
        self.put(self.base / "Game 3_v1/.proton/pfx/drive_c/other.dat")
        current = self.base / "Game 2_v2"
        current.mkdir()
        candidates = launcher.prefix_candidates(current, current.name, self.env)
        self.assertEqual(candidates[0]["prefix"], legacy)
        self.assertTrue(candidates[0]["same_game"])
        self.assertFalse(candidates[1]["same_game"])
        self.put(current / "Game.exe")
        os.chdir(current)
        with patch.object(launcher.sys.stdin, "isatty", return_value=True), \
             patch.object(launcher, "choose", side_effect=lambda choices, **kw: choices[0]):
            self.assertEqual(self.launch("--exe", "Game.exe"), legacy)
        self.assertEqual((legacy / "pfx/drive_c/save.dat").read_text(), "keep")

    def test_local_prefix_and_overrides_bypass_chooser(self):
        self.put(self.root / "Game.exe")
        legacy = self.root / ".proton"
        self.put(legacy / "pfx/drive_c/save.dat")
        with patch.object(launcher, "choose", side_effect=AssertionError("unexpected chooser")):
            self.assertEqual(self.launch("--exe", "Game.exe"), legacy)
            explicit = self.base / "custom prefix"
            self.assertEqual(self.launch("--exe", "Game.exe", "--prefix", str(explicit)), explicit)
            self.env["STEAM_COMPAT_DATA_PATH"] = str(self.base / "env prefix")
            self.assertEqual(self.launch("--exe", "Game.exe"), self.base / "env prefix")
            self.assertEqual(self.launch("--exe", "Game.exe", "--prefix", str(explicit)), explicit)

    def test_new_prefix_retains_previous_choices_and_overrides_environment(self):
        self.put(self.root / "Game.exe")
        first = self.launch("--exe", "Game.exe")
        self.env["STEAM_COMPAT_DATA_PATH"] = str(first)
        second = self.launch("--exe", "Game.exe", "--new-prefix")
        self.assertNotEqual(first, second)
        del self.env["STEAM_COMPAT_DATA_PATH"]
        candidates = launcher.prefix_candidates(self.root, self.root.name, self.env)
        self.assertEqual({item["prefix"] for item in candidates}, {first, second})
        self.assertEqual(candidates[0]["prefix"], second)
        self.assertTrue(candidates[0]["remembered"])
        self.assertFalse(candidates[1]["remembered"])
        self.assertEqual(self.launch("--exe", "Game.exe"), second)

    def test_prefix_cancel_and_preview_leave_no_files(self):
        old = self.base / "Game_v1/.proton"
        self.put(old / "pfx/drive_c/save.dat")
        current = self.base / "Game_v2"
        self.put(current / "Game.exe")
        os.chdir(current)
        with patch.object(launcher.sys.stdin, "isatty", return_value=True), \
             patch.object(launcher, "choose", side_effect=SystemExit(130)):
            with self.assertRaises(SystemExit) as result:
                self.invoke("--exe", "Game.exe")
            self.assertEqual(result.exception.code, 130)
        self.assertFalse((self.base / "data").exists())
        with patch.object(launcher.sys.stdin, "isatty", return_value=True), \
             patch.object(launcher, "choose", side_effect=lambda choices, **kw: choices[-1]):
            self.assertIn("Prefix:", self.invoke("--exe", "Game.exe", "--dry-run"))
        self.assertFalse((self.base / "data").exists())
        self.assertFalse((current / ".proton").exists())

    def test_noninteractive_matching_requires_an_explicit_decision(self):
        self.put(self.base / "Game_v1/.proton/pfx/drive_c/save.dat")
        current = self.base / "Game_v2"
        self.put(current / "Game.exe")
        os.chdir(current)
        with patch.object(launcher.sys.stdin, "isatty", return_value=False):
            with self.assertRaisesRegex(launcher.LaunchError, "--list-prefixes"):
                self.invoke("--exe", "Game.exe", "--dry-run")
            self.assertIn("Prefix:", self.invoke("--exe", "Game.exe", "--new-prefix", "--dry-run"))
        self.assertFalse((self.base / "data").exists())

    def test_prefix_listing_and_name_override_do_not_need_steam_or_executables(self):
        self.env.pop("STEAM_DIR")
        self.put(self.base / "Game_v1/.proton/pfx/drive_c/save.dat")
        output = self.invoke("--list-prefixes", "--game-name", "Game")
        self.assertIn("Same game: Game_v1", output)
        self.assertFalse((self.base / "data").exists())

    def test_unrelated_game_defaults_to_new_and_reselection_is_remembered(self):
        self.put(self.base / "Other Game/.proton/pfx/drive_c/save.dat")
        self.put(self.root / "Game.exe")
        with patch.object(launcher.sys.stdin, "isatty", return_value=True), \
             patch.object(launcher, "choose", side_effect=lambda choices, **kw: choices[0]) as chooser:
            first = self.launch("--exe", "Game.exe")
        self.assertTrue(chooser.call_args.args[0][0].startswith("New separate prefix"))
        with patch.object(launcher.sys.stdin, "isatty", return_value=True), \
             patch.object(launcher, "choose", side_effect=lambda choices, **kw: next(
                 choice for choice in choices if choice.startswith("New separate prefix")
             )) as chooser:
            second = self.launch("--exe", "Game.exe", "--choose-prefix")
        self.assertEqual(chooser.call_args.kwargs["prompt"], "Prefix > ")
        self.assertNotEqual(first, second)
        self.assertEqual(self.launch("--exe", "Game.exe"), second)

    def test_new_version_suggests_the_most_recently_used_prefix_first(self):
        first = self.base / "prefix-a"
        second = self.base / "prefix-b"
        first.mkdir()
        second.mkdir()
        with patch.object(launcher.time, "time_ns", side_effect=[100, 200]):
            launcher.remember_prefix(self.base / "Game_v1", "Game_v1", first, self.env)
            launcher.remember_prefix(self.base / "Game_v2", "Game_v2", second, self.env)
        candidates = launcher.prefix_candidates(self.base / "Game_v3", "Game_v3", self.env)
        self.assertEqual([item["prefix"] for item in candidates], [second, first])

    def test_bad_history_and_missing_prefixes_are_ignored(self):
        history = self.base / "data/proton-game/history"
        self.put(history / "broken.json", "{")
        self.put(history / "list.json", "[]")
        self.put(history / "bad-types.json", json.dumps({"schema": 1, "root": 0}))
        prefix = self.base / "gone"
        prefix.mkdir()
        launcher.remember_prefix(self.root, self.root.name, prefix, self.env)
        prefix.rmdir()
        with patch.object(launcher.sys, "stderr", io.StringIO()) as errors:
            self.assertEqual(launcher.prefix_candidates(self.root, self.root.name, self.env), [])
        self.assertIn("ignoring unreadable prefix history", errors.getvalue())

    def test_explicit_helpers_allowed_but_external_executables_rejected(self):
        self.put(self.root / "unins000.exe")
        self.assertIn("unins000.exe", self.invoke("--exe", "unins000.exe", "--dry-run"))
        external = self.put(self.base / "outside.exe")
        with self.assertRaisesRegex(launcher.LaunchError, "inside the current directory"):
            self.invoke("--exe", str(external), "--dry-run")


if __name__ == "__main__":
    unittest.main()
