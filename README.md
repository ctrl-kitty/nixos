
# NixOS flake

This repo contains a flake-based NixOS configuration intended to be reused across multiple machines.

## Install / switch

1) Clone this repo onto the target machine.

2) Generate host hardware config (first time on a machine):

```bash
sudo nixos-generate-config --show-hardware-config > hosts/<host>/hardware-configuration.nix
```

Replace `<host>` with one of the flake hosts (see `hosts/`).

3) Build and switch:

```bash
sudo nixos-rebuild switch --flake .#<host>
```

Examples:

```bash
sudo nixos-rebuild switch --flake .#laptop
sudo nixos-rebuild switch --flake .#desktop
```

Optional: verify evaluation/build without switching:

```bash
nix flake show
sudo nixos-rebuild build --flake .#<host>
```

## Login screen and Xwayland

Both hosts use GDM with Niri as the default session. The login screen has a plain
graphite background, Inter typography, a compact form, and a 24-hour clock.
Form dimensions use font-relative units and follow each display's scaling.
English and Russian keyboard layouts are available. Customize it in
`modules/graphic/gdm.nix`; GNOME's high-contrast theme remains available through
the accessibility menu.

The desktop's GDM monitor layout is defined in `hosts/desktop/graphics.nix`:
the right 4K monitor is primary at 100 Hz / 150%, and the left 1080p monitor runs
at 60 Hz / 100%, with their bottom edges aligned. GDM uses its own `monitors.xml`
in logical coordinates; Niri's existing output configuration is separate.

`modules/graphic/niri.nix` pins xwayland-satellite to the upstream commit that
merged [the Steam and Unity popup-focus fix](https://github.com/Supreeeme/xwayland-satellite/pull/494).
The source and Cargo dependencies are hash-pinned until a release includes it.

To apply the display-manager change at the next boot, build a boot generation,
then reboot when convenient (use `laptop` on the laptop):

```bash
sudo nixos-rebuild boot --flake .#desktop
```

## Run Windows games from a directory

The local `proton-game` package is installed on both hosts. After rebuilding and
opening a new shell, use its `prun` alias inside a game's directory:

```bash
cd /path/to/game
prun
```

An `fzf` chooser lists `.exe` files in this directory and its subfolders. Press
Enter to launch, or Esc to cancel. Unity/Unreal crash handlers, uninstallers,
DirectX/Visual C++/.NET installers, and redistributable folders are hidden by
default. Normal game launchers and `start_protected_game.exe` remain selectable.
`--all` includes filtered helpers; Wine/Proton prefixes and version-control
directories are always skipped, and directory symlinks are not traversed.

```bash
prun --all                              # Also show helper executables
prun --list                             # List candidates without launching
prun --dry-run                          # Choose and inspect the launch command
prun --exe 'Retail/My Game.exe' -- -windowed
prun --proton '/path/to/GE-Proton' --log
```

The launcher prefers installed Proton Experimental, then Hotfix, then other
installed Proton builds. It discovers additional Steam libraries and reads
Proton's manifest to select the required Steam Linux Runtime, using `steam-run`
for NixOS. Install Proton and its runtime through Steam first; `--proton` or
`PROTON_PATH` selects a particular build. `STEAM_DIR` and `STEAM_RUNTIME_PATH`
override discovery. This does not guarantee compatibility with every game.

Each directory gets its own `.proton/` data directory, compatible with the earlier
per-game launcher. Always start from the same game root to reuse saves/settings;
`--prefix PATH` or `STEAM_COMPAT_DATA_PATH` overrides that location. The selected
executable runs with its own parent directory as the working directory. `--appid`
sets a Steam app ID for title-specific Proton fixes; otherwise `SteamAppId` or `0`
is used. Proton options from the environment, including Wayland/HDR/NTSYNC
settings, pass through unchanged. `--log` enables `steam-<appid>.log` in the game
root (or `PROTON_LOG_DIR` when set).

To use the package before rebuilding, run it from a game directory:

```bash
nix run path:/home/ktvsky/.dotfiles/nixos#proton-game
```

Build and validate the package without launching a game:

```bash
nix build path:.#proton-game
./result/bin/proton-game --help
```

## Desktop applications and file associations

Both hosts use Dolphin (`Super+E`) and Kate. LibreOffice remains installed for
office documents. Default file handlers are defined in
`modules/graphic/file-associations.nix`:

| Files | Default application |
| --- | --- |
| Directories | Dolphin |
| PDF, HTML/XHTML, SVG, HTTP/HTTPS links | Firefox |
| Plain text, Markdown, JSON, YAML, TOML, XML, shell scripts | Kate |
| DOC/DOCX, ODT, RTF and document templates | LibreOffice Writer |
| XLS/XLSX, ODS, CSV/TSV and spreadsheet templates | LibreOffice Calc |
| PPT/PPTX, ODP and presentation templates | LibreOffice Impress |
| OpenDocument drawings, databases and formulae | LibreOffice Draw/Base/Math |
| Common video formats | mpv |

Defaults live in `/etc/xdg/mimeapps.list`. Both `~/.config/mimeapps.list` and the
legacy `~/.local/share/applications/mimeapps.list` point outside the Nix store to
the writable `~/.dotfiles/nixos/home/modules/xdg/mimeapps.list`. GUI choices
therefore change this repository file directly, as with the VS Code settings.
Commit/push it and pull on the other host to transfer preferences; Git does not
synchronize them automatically. Both hosts must keep the checkout at this path.
The shared file starts empty so the system defaults apply until explicitly
overridden. Home Manager replaces its old generated links on activation; any
pre-existing regular user file is backed up using the configured `.hmbackup`
suffix, and its entries can be merged into the shared file if needed.

In Dolphin, use **Open With**, choose an application, and enable **Remember
application association** to change the default; a one-time Open With choice does
not change it. User preferences survive later switches and take precedence over
system defaults. This follows the
[XDG MIME Applications specification](https://specifications.freedesktop.org/mime-apps/latest-single/).

Dolphin includes KIO network-file support, the KDE association editor and an XDG
application menu for use outside Plasma. GTK open/save dialogs still show hidden
files. Neovim remains available through Open With and now receives the selected
file paths.

The application inventory already covers archives (Ark), images (qimgv), drawing
(Pinta/Aseprite), video (mpv), music (Elisa), recording (OBS), screenshots (Niri),
notes (Logseq/Obsidian), and system monitoring (bottom). Based on this flake,
useful additions to consider separately are:

- [`kdePackages.kcalc`](https://apps.kde.org/kcalc/): a standalone graphical calculator.
- [`kdePackages.filelight`](https://apps.kde.org/filelight/): a graphical disk-space
  map; the existing `du-dust` and `duf` cover terminal usage.
- [`keepassxc`](https://keepassxc.org/): a standalone password database if the
  browser's password manager is insufficient.
- [`restic`](https://restic.net/): scheduled backups after choosing a destination
  and retention policy; no backup service is currently configured in this flake.

These optional applications have not been added. File synchronization and
Home Manager's `.hmbackup` files are not a substitute for backups of personal data.

## Editable application configuration: guidance for agents

Before adding or changing application configuration, check whether the application
edits it through its GUI and whether the file contains sensitive or host-specific
data. If a non-sensitive configuration can reasonably be shared, **ask the user
whether it should live in this repository and move between hosts, or remain local**.
Do not silently choose host-local storage. If the user has already stated their
preference in the current task, follow it without asking again.

For non-sensitive preferences edited through a GUI, prefer a normal tracked file
in `home/modules/<application>/` with a writable link from the application's
configuration location. Use Home Manager's `config.lib.file.mkOutOfStoreSymlink`
with an **absolute string path to the checkout**, as in
`home/modules/xdg/mimeapps.nix`. A relative Nix path such as `./settings.json`
would be copied into the read-only Nix store. Keep Home Manager's generator for
that same file disabled, and avoid `force = true` so existing unmanaged settings
can be backed up instead of discarded. Check that saving through the application
updates the repository file and preserves the link.

Keep settings intended to be fully declarative in Nix options. Credentials,
tokens, cookies, private history and machine-specific state must stay out of
shared configuration files; use the existing secrets setup or local storage as
appropriate. Check the actual contents rather than assuming every settings file
is safe to track.

Explain the transfer workflow: GUI changes appear in `git diff`; commit/push on
one host and pull on the other carries those preferences across. Links are
created on the next configuration activation. Later edits to linked files need
no Nix rebuild, although the application may need to reload or restart. This
does not provide automatic synchronization or conflict resolution.

## New module creation rules
If possible - use home manager instead of system module
Use 
```
  options.programs.androidVm = {
    enable = lib.mkEnableOption "BlissOS Android 13 QEMU VM";
  };
```
to make config easier to understand. So in future we can just enable modules without addition configuration.
## Folder structure rules

- `flake.nix`
  - Entry point.
  - `nixosConfigurations.<host>` defines the supported hosts.

- `configuration.nix`
  - Shared (host-agnostic) NixOS configuration.
  - Must NOT import any host-specific `hardware-configuration.nix`.
  - Put global services/users/packages here (or in `modules/`).

- `hosts/<host>/`
  - Per-host modules only.
  - `hosts/<host>/default.nix` is the host entry module (imported by `flake.nix`).
  - `hosts/<host>/hardware-configuration.nix` is generated by `nixos-generate-config` and contains disks/filesystems/kernel module detection.
  - `hosts/<host>/graphics.nix` contains GPU/video driver settings for that host.

- `modules/`
  - Reusable NixOS modules shared by multiple hosts.
  - Keep these hardware-agnostic (no disk UUIDs, no PCI bus IDs) unless the module is explicitly host-specific and lives under `hosts/<host>/`.

- `home/`
  - Home Manager integration.
  - `home/default.nix` wires Home Manager into the NixOS config.
  - `home/modules/` contains reusable HM modules.

## flakeHost usage

`flakeHost` is injected into all modules via `specialArgs` in `flake.nix`.
Use it to keep host-specific logic inside shared modules.

Example (NixOS module):

```nix
{ lib, flakeHost, ... }:

lib.mkIf (flakeHost == "desktop") {
  services.openssh.enable = true;
}
```

Example (HM override with host-specific files):

```nix
{ lib, flakeHost, ... }:

let
  desktopConfig =
    builtins.readFile ../../home/modules/niri/config.kdl
    + "\n\n"
    + builtins.readFile ../../home/modules/niri/desktop-outputs.kdl;
in
lib.mkIf (flakeHost == "desktop") {
  home-manager.users.ktvsky.xdg.configFile."niri/config.kdl" =
    lib.mkForce { text = desktopConfig; };
}
```

## Notes

- Root-level `hardware-configuration.nix` is intentionally not used; host configs live under `hosts/<host>/`.
