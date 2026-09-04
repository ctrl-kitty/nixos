{ stdenv, lib, fetchurl, cmake, pkg-config, glib, gtk3, gobject-introspection, vala }:

stdenv.mkDerivation rec {
  pname = "libayatana-ido";
  version = "0.10.4";

  src = fetchurl {
    url = "https://github.com/AyatanaIndicators/ayatana-ido/archive/refs/tags/${version}.tar.gz";
    sha256 = "sha256-vVmr1fExTkEdDVXONkPpHO9jMnH1gSa+Up3l+3HFqzg=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    gobject-introspection
    vala
  ];

  buildInputs = [
    glib
    gtk3
    gobject-introspection
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DENABLE_TESTS=OFF"
    "-DENABLE_COVERAGE=OFF"
  ];

  meta = {
    description = "Ayatana Indicators Display Objects library";
    homepage = "https://github.com/AyatanaIndicators/ayatana-ido";
    # tri-licensed GPL-3 / LGPL-2 / LGPL-3; use the most permissive
    license = lib.licenses.lgpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
