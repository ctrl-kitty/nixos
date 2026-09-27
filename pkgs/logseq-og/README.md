# Logseq OG attachment links and text previews

Both NixOS hosts use the following patches on top of the pinned Electron 43
compatibility patch:

- `open-local-files.patch`: handles `file://` links through the native shell,
  since Chromium blocks navigation from the `lsp://` renderer. Only the main
  Logseq document handles these clicks; browser security remains enabled.
- `preview-local-files.patch`: ordinary text attachment links open Logseq's
  existing file viewer, and PDF links open the built-in PDF viewer. TXT links
  show the same Tippy hover card used by page references, after a one-second
  delay. Local PDF bytes pass through the Electron preload bridge because
  PDF.js cannot fetch local URLs from the lsp renderer. Unsupported formats
  retain the system application fallback.

The preview is plain text, preserving whitespace and displaying markup literally.
It reads at most 8193 bytes on hover and shows at most 4000 UTF-16 code units.
Empty files and read errors have explicit messages. The full text opens on click;
page Markdown links keep their existing semantics. No graph migration or changes
to note contents are needed.

Build or run without switching the system (close the existing Logseq instance
before launching the new one):

```sh
nix build path:.#logseq-og -o /tmp/logseq-og-preview
/tmp/logseq-og-preview/bin/logseq-og
```

The reader test uses the actual packaged preload and real temporary files:

```sh
node pkgs/logseq-og/test-text-preview.cjs \
  /tmp/logseq-og-preview/share/logseq-og/resources/app/js/preload.js
```

Run the Electron tests in a graphical session:

```sh
nix shell .#nixosConfigurations.desktop.pkgs.unstable.electron_43 -c \
  electron pkgs/logseq-og/test-file-links.cjs \
  /tmp/logseq-og-preview/share/logseq-og/resources/app/js/preload.js
nix shell .#nixosConfigurations.desktop.pkgs.unstable.electron_43 -c \
  electron pkgs/logseq-og/test-attachment-ui.cjs \
  /tmp/logseq-og-preview/share/logseq-og/resources/app
```

The first test checks the native-opening fallback with a stubbed shell boundary.
The UI test launches the actual packaged Logseq with separate home/profile paths
and a temporary graph under `/tmp`. It checks hover, empty/missing files, literal
markup, special filenames, full text and the PDF viewer, and saves screenshots.
User notes and the regular Logseq profile are not used.
