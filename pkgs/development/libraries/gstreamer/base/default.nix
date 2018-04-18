{ stdenv, fetchurl, fetchpatch, pkgconfig, meson
, ninja, gettext, gobjectIntrospection, python
, gstreamer, orc, alsaLib, libXv, pango, libtheora
, wayland, cdparanoia, libvisual, libintl
}:

stdenv.mkDerivation rec {
  name = "gst-plugins-base-1.14.0";

  meta = {
    description = "Base plugins and helper libraries";
    homepage = https://gstreamer.freedesktop.org;
    license = stdenv.lib.licenses.lgpl2Plus;
    platforms = stdenv.lib.platforms.unix;
  };

  src = fetchurl {
    url = "${meta.homepage}/src/gst-plugins-base/${name}.tar.xz";
    sha256 = "0h39bcp7fcd9kgb189lxr8l0hm0almvzpzgpdh1jpq2nzxh4d43y";
  };

  outputs = [ "out" "dev" ];

  # including meson and ninja here completely change the build
  # homebrew uses standard ./configure && make && make install
  # Unclear to how to pass feature options to meson
  # and the build explodes on a path including x11
  nativeBuildInputs = [
    pkgconfig python gettext gobjectIntrospection
  ];

  buildInputs = [
    orc libXv pango libtheora cdparanoia libintl
  ]
  ++ stdenv.lib.optionals stdenv.isLinux [ alsaLib wayland ]
  ++ stdenv.lib.optional (!stdenv.isDarwin) libvisual;

  propagatedBuildInputs = [ gstreamer ];

  preConfigure = ''
    patchShebangs .
  '';

  # Untested
  configureFlags = stdenv.lib.optionals stdenv.isDarwin [
    "--without-x"
    "--disable-x"
    "--disable-xvideo"
    "--disable-xshm"
  ];

  enableParallelBuilding = true;

  patches = [
    (fetchpatch {
        url = "https://bug794856.bugzilla-attachments.gnome.org/attachment.cgi?id=370414";
        sha256 = "07x43xis0sr0hfchf36ap0cibx0lkfpqyszb3r3w9dzz301fk04z";
    })
    ./fix_pkgconfig_includedir.patch
  ];
}
