{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  mesonEmulatorHook,
  ninja,
  pkg-config,
  gobject-introspection,
  gtk-doc,
  docbook-xsl-nons,
  docbook_xml_dtd_43,
  glib,
  buildPackages,
  withIntrospection ?
    lib.meta.availableOn stdenv.hostPlatform gobject-introspection
    && stdenv.hostPlatform.emulatorAvailable buildPackages,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "libqrtr-glib";
  version = "1.2.2";

  outputs = [
    "out"
    "dev"
  ]
  ++ lib.optional withIntrospection "devdoc";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "mobile-broadband";
    repo = "libqrtr-glib";
    rev = finalAttrs.version;
    sha256 = "kHLrOXN6wgBrHqipo2KfAM5YejS0/bp7ziBSpt0s1i0=";
  };

  strictDeps = true;

  depsBuildBuild = [
    pkg-config
  ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ]
  ++ lib.optionals withIntrospection [
    gobject-introspection
    gtk-doc
    docbook-xsl-nons
    docbook_xml_dtd_43
  ]
  ++ lib.optionals (withIntrospection && !stdenv.buildPlatform.canExecute stdenv.hostPlatform) [
    mesonEmulatorHook
  ];

  buildInputs = [
    glib
  ];

  mesonFlags = [
    (lib.mesonBool "introspection" withIntrospection)
    (lib.mesonBool "gtk_doc" withIntrospection)
  ];

  meta = {
    homepage = "https://gitlab.freedesktop.org/mobile-broadband/libqrtr-glib";
    description = "Qualcomm IPC Router protocol helper library";
    teams = [ lib.teams.freedesktop ];
    platforms = lib.platforms.linux;
    license = lib.licenses.lgpl2Plus;
  };
})
