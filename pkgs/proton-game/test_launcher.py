"""Regression checks for filtering and the launch boundary; never start a game."""

from contextlib import redirect_stdout
import importlib.util
import io
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
        self.env = {"STEAM_DIR": str(self.steam)}

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
        self.assertEqual(env["STEAM_COMPAT_DATA_PATH"], str(self.root / ".proton"))
        self.assertTrue((self.root / ".proton").is_dir())
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

    def test_explicit_helpers_allowed_but_external_executables_rejected(self):
        self.put(self.root / "unins000.exe")
        self.assertIn("unins000.exe", self.invoke("--exe", "unins000.exe", "--dry-run"))
        external = self.put(self.base / "outside.exe")
        with self.assertRaisesRegex(launcher.LaunchError, "inside the current directory"):
            self.invoke("--exe", str(external), "--dry-run")


if __name__ == "__main__":
    unittest.main()
