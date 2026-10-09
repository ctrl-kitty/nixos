"""Terminal chooser for games, using installed Proton and Steam Linux Runtime."""

import argparse
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import unicodedata
import uuid


# Match helper names, never arbitrary occurrences of "crash", "setup" or "launcher".
HELPER_NAMES = (
    "unitycrashhandler*.exe", "crashreportclient*.exe", "crashreporter*.exe",
    "crashreport.exe", "installermessage.exe",
    "crashpad_handler*.exe", "ue4prereqsetup*.exe", "ueprereqsetup*.exe",
    "dxsetup.exe", "dxwebsetup.exe", "vcredist*.exe", "vc_redist*.exe",
    "dotnetfx*.exe", "ndp[0-9]*.exe", "dotnet-runtime*.exe",
    "windowsdesktop-runtime*.exe", "oalinst.exe", "physx*.exe",
    "unins[0-9]*.exe", "uninstall.exe", "uninstaller.exe", "uninstall_*.exe",
    "setup.exe", "setup32.exe", "setup64.exe", "install.exe", "installer.exe",
    "easyanticheat_setup.exe", "easyanticheat_eos_setup.exe", "beservice*.exe",
    "werfault.exe", "werfaultsecure.exe", "python.exe", "pythonw.exe", "zsync.exe",
    "zsyncmake.exe",
)
HELPER_DIRS = {
    "_commonredist", "_redist", "redist", "redistributables", "directx",
    "vcredist", "_installer", "installers", "crashreportclient",
    "_crack", "_original files", "_extras", "lib"
}
INTERNAL_DIRS = {".git", ".hg", ".svn", ".proton", ".wine", "compatdata",}


class LaunchError(Exception):
    pass


def is_prefix(path):
    return (path / "pfx" / "drive_c").is_dir() or (
        (path / "drive_c").is_dir() and (path / "system.reg").is_file()
    )


def executables(root, show_all=False):
    result = []
    for directory, dirs, files in os.walk(root):
        base = Path(directory)
        dirs[:] = [
            name for name in dirs
            if name.casefold() not in INTERNAL_DIRS
            and not is_prefix(base / name)
            and (show_all or name.casefold() not in HELPER_DIRS)
        ]
        for name in files:
            path = base / name
            if path.suffix.casefold() != ".exe" or not path.is_file():
                continue
            if not path.resolve().is_relative_to(root):
                continue
            if not show_all and any(
                fnmatch.fnmatchcase(name.casefold(), pattern) for pattern in HELPER_NAMES
            ):
                continue
            result.append(path.relative_to(root).as_posix())
    return sorted(result, key=lambda name: (name.count("/"), name.casefold()))


def choose(candidates, prompt="Game > ", header=None):
    if not sys.stdin.isatty():
        raise LaunchError("The chooser needs a terminal. Use --list or --exe PATH.")
    env = os.environ.copy()
    # User-wide fzf bindings/options must not alter the returned filename format.
    env.pop("FZF_DEFAULT_OPTS", None)
    env.pop("FZF_DEFAULT_OPTS_FILE", None)
    result = subprocess.run(
        ["fzf", "--read0", "--print0", "--no-multi", "--layout=reverse",
         "--height=70%", "--border", "--no-sort", f"--prompt={prompt}",
         "--header=" + (header or "Enter: launch | Esc: cancel | --all: include helper executables")],
        input=b"\0".join(os.fsencode(name) for name in candidates) + b"\0",
        stdout=subprocess.PIPE, env=env, check=False,
    )
    if result.returncode in (1, 130):
        raise SystemExit(130)
    if result.returncode:
        raise LaunchError(f"fzf failed with exit code {result.returncode}.")
    selected = os.fsdecode(result.stdout.removesuffix(b"\0"))
    if selected not in candidates:
        raise LaunchError("The chooser did not return a listed executable.")
    return selected


# Only strip suffixes with version evidence. Plain numbers belong to the title:
# "Portal 2" and "Cyberpunk 2077" must remain distinct from other games.
VERSION_NUMBER = r"\d+(?:[._-]\d+)*(?:[a-z])?"
VERSION_SUFFIX = re.compile(
    r"(?:[\s._-]+|\s*[\[(])(?:"
    r"(?:v(?:ersion)?|ver|build|revision|rev|r|b|patch|update)[:\s._-]*" + VERSION_NUMBER +
    r"|\d+(?:[._]\d+){1,}(?:[a-z])?"
    r"|(?:19|20)\d{2}[-._]\d{2}[-._]\d{2}|(?:19|20)\d{6}"
    r")(?:[-._\s]*(?:alpha|beta|rc|pre|preview|hotfix|release|final|stable)"
    r"(?:[\s._-]*\d+)?)?(?:\+[-\w.]+)?[\])]?$"
)
PACKAGING_SUFFIX = re.compile(
    r"(?:[\s._-]+|\s*[\[(])(?:fitgirl[\s._-]+repack|dodi[\s._-]+repack|"
    r"repack|portable|gog|steam|multi\d+)[\])]?$"
)


def game_key(name):
    name = unicodedata.normalize("NFKC", name).casefold().strip()
    # Packaging tags are removed only when preceded by a recognizable version.
    without_packaging = name
    while match := PACKAGING_SUFFIX.search(without_packaging):
        without_packaging = without_packaging[:match.start()].rstrip(" ._-")
    if VERSION_SUFFIX.search(without_packaging):
        name = without_packaging
    while match := VERSION_SUFFIX.search(name):
        shortened = name[:match.start()].rstrip(" ._-")
        if not shortened:
            break
        name = shortened
    return " ".join(re.findall(r"[^\W_]+", name))


def helper_directory(env):
    default = Path.home() / ".local/share"
    base = Path(env.get("XDG_DATA_HOME") or default).expanduser()
    return (base if base.is_absolute() else default) / "proton-game"


def history_file(root, prefix, env):
    digest = hashlib.sha256(os.fsencode(root) + b"\0" + os.fsencode(prefix)).hexdigest()
    return helper_directory(env) / "history" / f"{digest}.json"


def prefix_history(env):
    records = []
    for path in sorted((helper_directory(env) / "history").glob("*.json")):
        try:
            record = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(record, dict) or record.get("schema") != 1:
                continue
            if not all(isinstance(record.get(key), str) for key in ("root", "title", "prefix")):
                continue
            if not isinstance(record.get("last_used_ns"), int):
                continue
            prefix = Path(record["prefix"])
            if prefix.is_absolute() and prefix.is_dir():
                records.append(record)
        except (OSError, ValueError):
            print(f"proton-game: ignoring unreadable prefix history: {path}", file=sys.stderr)
    return records


def prefix_candidates(root, title, env):
    """Discover history across game folders, plus legacy prefixes in siblings."""
    records = prefix_history(env)
    remembered = max((record for record in records if record["root"] == str(root)),
                     key=lambda record: record["last_used_ns"], default=None)
    if (root / ".proton").is_dir():
        records.append({"root": str(root), "title": title, "prefix": str(root / ".proton")})
    try:
        siblings = sorted(root.parent.iterdir())
    except OSError:
        siblings = []
    for sibling in siblings:
        if sibling != root and not sibling.is_symlink() and (sibling / ".proton").is_dir():
            records.append({"root": str(sibling), "title": sibling.name,
                            "prefix": str(sibling / ".proton")})
    candidates = {}
    for record in records:
        prefix = Path(record["prefix"]).resolve()
        same_game = bool(game_key(title)) and game_key(record["title"]) == game_key(title)
        is_remembered = record is remembered and same_game
        candidate = {"prefix": prefix, "title": record["title"],
                     "same_game": same_game, "remembered": is_remembered,
                     "last_used_ns": record.get("last_used_ns", 0)}
        previous = candidates.get(prefix)
        if previous is None or (is_remembered, same_game, candidate["last_used_ns"]) > (
            previous["remembered"], previous["same_game"], previous["last_used_ns"]
        ):
            candidates[prefix] = candidate
    return sorted(candidates.values(), key=lambda item: (
        not item["remembered"], not item["same_game"], -item["last_used_ns"],
        item["title"].casefold(), str(item["prefix"])
    ))


def prefix_label(candidate):
    kind = "Remembered" if candidate["remembered"] else "Same game" if candidate["same_game"] else "Other game"
    return f"{kind}: {candidate['title']} — {candidate['prefix']}"


def new_prefix(title, env):
    slug = re.sub(r"[^\w-]+", "-", game_key(title)).strip("-")[:48] or "game"
    return (helper_directory(env) / "prefixes" / f"{slug}-{uuid.uuid4().hex[:12]}").resolve()


def select_prefix(root, args, env):
    if args.prefix:
        return Path(args.prefix).expanduser().resolve()
    title = args.game_name or root.name
    if args.new_prefix:
        return new_prefix(title, env)
    if env.get("STEAM_COMPAT_DATA_PATH") and not args.choose_prefix:
        return Path(env["STEAM_COMPAT_DATA_PATH"]).expanduser().resolve()
    candidates = prefix_candidates(root, title, env)
    if not args.choose_prefix:
        remembered = next((item["prefix"] for item in candidates if item["remembered"]), None)
        if remembered:
            return remembered
        if (root / ".proton").is_dir():
            return (root / ".proton").resolve()
    fresh = new_prefix(title, env)
    if not args.choose_prefix and not candidates:
        return fresh
    if not sys.stdin.isatty():
        if args.choose_prefix or any(item["same_game"] for item in candidates):
            raise LaunchError("Prefix selection needs a terminal. Use --list-prefixes, then --prefix PATH, "
                              "or --new-prefix for a separate prefix.")
        return fresh
    choices = {prefix_label(item): item["prefix"] for item in candidates if item["same_game"]}
    choices[f"New separate prefix — {fresh}"] = fresh
    choices.update({prefix_label(item): item["prefix"] for item in candidates if not item["same_game"]})
    selected = choose(list(choices), prompt="Prefix > ",
                      header="Enter: use prefix | Esc: cancel | Similar names are suggestions; check the game title")
    return choices[selected]


def remember_prefix(root, title, prefix, env):
    """Keep previous choices too; separate atomic records avoid registry rewrites."""
    path = history_file(root, prefix, env)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False) as output:
            temporary = Path(output.name)
            json.dump({"schema": 1, "root": str(root), "title": title, "prefix": str(prefix),
                       "last_used_ns": time.time_ns()}, output)
            output.write("\n")
        temporary.replace(path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def vdf_values(path, key):
    if not path.is_file():
        return []
    text = path.read_text(encoding="utf-8", errors="replace")
    values = re.findall(r'"' + re.escape(key) + r'"\s*"((?:\\.|[^"\\])*)"', text)
    return [re.sub(r'\\([\\"])', r'\1', value) for value in values]


def unique_paths(paths):
    return list(dict.fromkeys(path.expanduser().resolve() for path in paths))


def steam_installation(env):
    explicit = env.get("STEAM_DIR") or env.get("STEAM_COMPAT_CLIENT_INSTALL_PATH")
    home = Path.home()
    roots = [Path(explicit)] if explicit else [
        Path(env.get("XDG_DATA_HOME", home / ".local/share")) / "Steam",
        home / ".steam/steam", home / ".steam/root",
        home / ".var/app/com.valvesoftware.Steam/data/Steam",
    ]
    for root in unique_paths(roots):
        if (root / "steamapps").is_dir():
            libraries = unique_paths([root] + [
                Path(value) for value in vdf_values(root / "steamapps/libraryfolders.vdf", "path")
            ])
            return root, libraries
    raise LaunchError("Steam installation not found. Set STEAM_DIR to its directory.")


def executable_file(path):
    return path.is_file() and os.access(path, os.X_OK)


def proton_installation(libraries, override):
    if override:
        path = Path(override).expanduser().resolve()
        if path.is_dir():
            path /= "proton"
        if not executable_file(path):
            raise LaunchError(f"Not a Proton executable: {path}")
        return path
    # Prefer Experimental across all libraries, then Hotfix, then other builds.
    for name in ("Proton - Experimental", "Proton Hotfix"):
        for library in libraries:
            path = library / "steamapps/common" / name / "proton"
            if executable_file(path):
                return path
    for library in libraries:
        candidates = list((library / "compatibilitytools.d").glob("*/proton"))
        candidates += list((library / "steamapps/common").glob("Proton */proton"))
        for path in sorted(candidates, reverse=True):
            if executable_file(path):
                return path
    raise LaunchError("No installed Proton found. Install it in Steam or set PROTON_PATH.")


def runtime_installation(proton, libraries, override):
    if override:
        runtime = Path(override).expanduser().resolve()
        if not executable_file(runtime / "_v2-entry-point"):
            raise LaunchError(f"Invalid STEAM_RUNTIME_PATH: {runtime}")
        return runtime
    manifests = [proton.parent / "toolmanifest.vdf", proton.parent / "toolmanifest_x86_64.vdf"]
    required = next((ids for path in manifests if (ids := vdf_values(path, "require_tool_appid"))), [])
    if not required:
        raise LaunchError("Proton's runtime dependency is unknown. Set STEAM_RUNTIME_PATH.")
    appid = required[0]
    if not appid.isdecimal():
        raise LaunchError("Invalid runtime app ID in Proton's toolmanifest.vdf.")
    for library in libraries:
        manifest = library / "steamapps" / f"appmanifest_{appid}.acf"
        for name in vdf_values(manifest, "installdir"):
            path = library / "steamapps/common" / name
            if executable_file(path / "_v2-entry-point"):
                return path
    raise LaunchError(f"Required Steam Linux Runtime ({appid}) is missing. Install it in Steam or set STEAM_RUNTIME_PATH.")


def launch_plan(root, exe, args, env, prefix):
    steam, libraries = steam_installation(env)
    proton = proton_installation(libraries, args.proton or env.get("PROTON_PATH"))
    runtime = runtime_installation(proton, libraries, env.get("STEAM_RUNTIME_PATH"))
    appid = args.appid or env.get("SteamAppId") or "0"
    if not appid.isdecimal():
        raise LaunchError("Steam app ID must be a non-negative integer.")
    env = env.copy()
    env.update({
        "STEAM_COMPAT_CLIENT_INSTALL_PATH": str(steam),
        "STEAM_COMPAT_DATA_PATH": str(prefix),
        "STEAM_COMPAT_INSTALL_PATH": str(root),
        "STEAM_COMPAT_TOOL_PATHS": f"{proton.parent}:{runtime}",
        "STEAM_COMPAT_APP_ID": appid,
        "SteamAppId": appid,
        "SteamGameId": appid,
    })
    env.setdefault("PROTON_LOG_DIR", str(root))
    if args.log:
        env["PROTON_LOG"] = "1"
    command = ["steam-run", str(runtime / "_v2-entry-point"), "--verb=waitforexitandrun",
               "--", str(proton), "waitforexitandrun", str(exe), *args.game_args]
    return command, env, prefix


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="proton-game",
        description="Choose a Windows game in the current directory (including subfolders) and run it with Proton.",
        epilog="New prefixes use $XDG_DATA_HOME/proton-game/prefixes (default: ~/.local/share). "
               "Suggests existing prefixes for updated games and remembers your choice. "
               "Steam and Proton must already be installed. "
               "Environment: STEAM_DIR, PROTON_PATH, STEAM_RUNTIME_PATH, STEAM_COMPAT_DATA_PATH. "
               "Pass game arguments after --. Existing Proton environment options are preserved.",
    )
    parser.add_argument("--all", action="store_true", help="include installers, crash handlers and other helpers")
    parser.add_argument("--list", action="store_true", help="list candidates without opening the chooser")
    parser.add_argument("--list-prefixes", action="store_true", help="list known prefixes, matching games first; no launch")
    parser.add_argument("--exe", metavar="PATH", help="select an executable under the current directory directly")
    parser.add_argument("--proton", metavar="PATH", help="use a specific Proton directory or executable")
    prefix_options = parser.add_mutually_exclusive_group()
    prefix_options.add_argument("--prefix", metavar="PATH", help="use a specific Proton data directory (contains pfx/)")
    prefix_options.add_argument("--choose-prefix", action="store_true", help="choose again from known prefixes or create a new one")
    prefix_options.add_argument("--new-prefix", action="store_true", help="create a separate shared prefix without asking")
    parser.add_argument("--game-name", metavar="NAME", help="override the game name used to suggest matching prefixes")
    parser.add_argument("--appid", metavar="ID", help="Steam app ID for title-specific Proton fixes (default: SteamAppId or 0)")
    parser.add_argument("--log", action="store_true", help="enable Proton logging in the current directory")
    parser.add_argument("--dry-run", action="store_true", help="show the launch without creating files or starting the game")
    parser.add_argument("game_args", nargs=argparse.REMAINDER, help="arguments passed to the selected executable")
    args = parser.parse_args(argv)
    if args.game_args[:1] == ["--"]:
        args.game_args = args.game_args[1:]
    root = Path.cwd()
    if args.list_prefixes:
        if args.list or args.exe:
            parser.error("--list-prefixes cannot be used with --list or --exe")
        for candidate in prefix_candidates(root, args.game_name or root.name, os.environ):
            print(prefix_label(candidate))
        return 0
    if args.exe and args.list:
        parser.error("--exe and --list cannot be used together")
    if args.exe:
        exe = Path(args.exe).expanduser().resolve()
    else:
        candidates = executables(root, args.all)
        if not candidates:
            raise LaunchError("No game executables found. Try --all to include helper executables.")
        if args.list:
            for candidate in candidates:
                print(candidate)
            return 0
        exe = (root / choose(candidates)).resolve()
    if not exe.is_relative_to(root) or not exe.is_file() or exe.suffix.casefold() != ".exe":
        raise LaunchError("Select an existing .exe inside the current directory.")
    prefix = select_prefix(root, args, os.environ)
    command, env, prefix = launch_plan(root, exe, args, os.environ, prefix)
    print(f"Game: {exe.relative_to(root)}\nPrefix: {prefix}\nWorking directory: {exe.parent}", flush=True)
    if args.dry_run:
        for key in sorted(env):
            if key.startswith(("STEAM_COMPAT_", "PROTON_", "DXVK_", "VKD3D_")) or key in {"SteamAppId", "SteamGameId"}:
                print(f"{key}={shlex.quote(env[key])}")
        print("Command: " + shlex.join(command))
        return 0
    if not shutil.which(command[0]):
        raise LaunchError("steam-run is missing from PATH.")
    prefix.mkdir(parents=True, exist_ok=True)
    remember_prefix(root, args.game_name or root.name, prefix, os.environ)
    os.chdir(exe.parent)
    os.execvpe(command[0], command, env)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except (LaunchError, OSError) as error:
        print(f"proton-game: {error}", file=sys.stderr)
        sys.exit(1)
