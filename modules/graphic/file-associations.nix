{ lib, ... }:
let
  associate = desktop: types: lib.genAttrs types (_: desktop);
in
{
  # /etc/xdg/mimeapps.list supplies fallbacks. ~/.config/mimeapps.list belongs
  # to the user and takes precedence, including after later system switches.
  xdg.mime.defaultApplications =
    associate "firefox.desktop" [
      "application/pdf"
      "application/xhtml+xml"
      "text/html"
      "image/svg+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ]
    // associate "org.kde.dolphin.desktop" [ "inode/directory" ]
    // associate "org.kde.kate.desktop" [
      "text/plain"
      "text/markdown"
      "text/x-log"
      "text/x-readme"
      "application/json"
      "application/xml"
      "text/xml"
      "application/yaml"
      "application/x-yaml"
      "text/yaml"
      "text/x-yaml"
      "application/toml"
      "application/x-shellscript"
    ]
    // associate "mpv.desktop" [
      "video/mp4"
      "video/x-matroska"
      "video/webm"
      "video/x-msvideo"
      "video/quicktime"
      "video/mpeg"
    ]
    // associate "writer.desktop" [
      "application/msword"
      "application/vnd.ms-word"
      "application/vnd.ms-word.document.macroEnabled.12"
      "application/vnd.ms-word.template.macroEnabled.12"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
      "application/vnd.oasis.opendocument.text"
      "application/vnd.oasis.opendocument.text-template"
      "application/vnd.oasis.opendocument.text-master"
      "application/vnd.oasis.opendocument.text-flat-xml"
      "application/rtf"
      "text/rtf"
    ]
    // associate "calc.desktop" [
      "application/vnd.ms-excel"
      "application/vnd.ms-excel.sheet.macroEnabled.12"
      "application/vnd.ms-excel.sheet.binary.macroEnabled.12"
      "application/vnd.ms-excel.template.macroEnabled.12"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.template"
      "application/vnd.oasis.opendocument.spreadsheet"
      "application/vnd.oasis.opendocument.spreadsheet-template"
      "application/vnd.oasis.opendocument.spreadsheet-flat-xml"
      "text/csv"
      "text/tab-separated-values"
    ]
    // associate "impress.desktop" [
      "application/vnd.ms-powerpoint"
      "application/vnd.ms-powerpoint.presentation.macroEnabled.12"
      "application/vnd.ms-powerpoint.slideshow.macroEnabled.12"
      "application/vnd.ms-powerpoint.template.macroEnabled.12"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      "application/vnd.openxmlformats-officedocument.presentationml.slideshow"
      "application/vnd.openxmlformats-officedocument.presentationml.slide"
      "application/vnd.openxmlformats-officedocument.presentationml.template"
      "application/vnd.oasis.opendocument.presentation"
      "application/vnd.oasis.opendocument.presentation-template"
      "application/vnd.oasis.opendocument.presentation-flat-xml"
    ]
    // associate "draw.desktop" [
      "application/vnd.oasis.opendocument.graphics"
      "application/vnd.oasis.opendocument.graphics-template"
      "application/vnd.oasis.opendocument.graphics-flat-xml"
    ]
    // associate "base.desktop" [ "application/vnd.oasis.opendocument.base" ]
    // associate "math.desktop" [ "application/vnd.oasis.opendocument.formula" ];

  # Make Firefox discoverable for PDF/SVG even if its desktop entry only lists
  # web content, and keep Neovim available as an explicit alternative to Kate.
  xdg.mime.addedAssociations = {
    "application/pdf" = "firefox.desktop";
    "image/svg+xml" = "firefox.desktop";
    "text/plain" = [
      "org.kde.kate.desktop"
      "nvim.desktop"
    ];
  };
}
