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
- `fix-previews-and-pdf.patch`: Markdown attachments (both `[label](file.md)`
  and `![label](file.md)`) have a formatted hover preview. Attachment cards use
  the bounded reader and sanitized HTML. Indexed Markdown files and
  wiki page links keep Logseq's native page previews and navigation. File links
  resolve the indexed page by target path, not by display label; otherwise
  a link such as `[Read this](../pages/Actual.md)` previews an empty `Read this` page.
  PDFs follow the application theme by default; `Auto` in the PDF theme picker
  restores this after choosing a fixed light/warm/dark theme. The old implicit
  `light` preference is replaced by Auto on the first run of this patch.
  PDF.js prepares two adjacent pages, with visible pages retaining priority
  and its normal bounded canvas cache. GPU flags and drivers are unchanged.

TXT previews preserve whitespace and display markup literally. Both TXT and
Markdown previews read at most 8193 bytes on hover and use at most 4000 UTF-16
code units.
Empty files and read errors have explicit messages. The full text opens on click.
Indexed Markdown page links keep native page navigation and hover. No graph
migration or changes to note contents are needed.

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
markup, special filenames, full text, Markdown attachment/page previews,
application/PDF theme changes, manual overrides and preparation of subsequent
PDF pages before scrolling. It saves screenshots; `--pdf-only` selects the
PDF cases. This verifies preparation, not a guaranteed frame rate for all PDFs.
User notes and the regular Logseq profile are not used.
