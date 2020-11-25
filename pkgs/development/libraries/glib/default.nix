{ config, lib, stdenv, fetchurl, gettext, meson, ninja, pkg-config, perl, python3
, libiconv, zlib, libffi, pcre, libelf, gnome3, libselinux, bash, gnum4, gtk-doc, docbook_xsl, docbook_xml_dtd_45
# use util-linuxMinimal to avoid circular dependency (util-linux, systemd, glib)
, util-linuxMinimal ? null
, buildPackages

# this is just for tests (not in the closure of any regular package)
, doCheck ? config.doCheckByDefault or false
, coreutils, dbus, libxml2, tzdata
, desktop-file-utils, shared-mime-info
, darwin, fetchpatch
}:

with lib;

assert stdenv.isLinux -> util-linuxMinimal != null;

# TODO:
# * Make it build without python
#     Problem: an example (test?) program needs it.
#     Possible solution: disable compilation of this example somehow
#     Reminder: add 'sed -e 's@python2\.[0-9]@python@' -i
#       $out/bin/gtester-report' to postInstall if this is solved
/*
  * Use --enable-installed-tests for GNOME-related packages,
      and use them as a separately installed tests runned by Hydra
      (they should test an already installed package)
      https://wiki.gnome.org/GnomeGoals/InstalledTests
  * Support org.freedesktop.Application, including D-Bus activation from desktop files
*/
let
  # Some packages don't get "Cflags" from pkg-config correctly
  # and then fail to build when directly including like <glib/...>.
  # This is intended to be run in postInstall of any package
  # which has $out/include/ containing just some disjunct directories.
  flattenInclude = ''
    for dir in "''${!outputInclude}"/include/*; do
      cp -r "$dir"/* "''${!outputInclude}/include/"
      rm -r "$dir"
      ln -s . "$dir"
    done
    ln -sr -t "''${!outputInclude}/include/" "''${!outputInclude}"/lib/*/include/* 2>/dev/null || true
  '';
in

stdenv.mkDerivation rec {
  pname = "glib";
  version = "2.66.4";

  src = fetchurl {
    url = "mirror://gnome/sources/glib/${lib.versions.majorMinor version}/${pname}-${version}.tar.xz";
    sha256 = "l9+GcOMvn9T3OSsJgOZh3WJQEgFdWDUNoeWOND9K+YQ=";
  };

  patches = optionals stdenv.isDarwin [
    ./darwin-compilation.patch
    ./link-with-coreservices.patch
  ] ++ optionals stdenv.hostPlatform.isMusl [
    ./quark_init_on_demand.patch
    ./gobject_init_on_demand.patch
  ] ++ [
    ./schema-override-variable.patch

    # GLib contains many binaries used for different purposes;
    # we will install them to different outputs:
    # 1. Tools for desktop environment ($bin)
    #    * gapplication (non-darwin)
    #    * gdbus
    #    * gio
    #    * gio-launch-desktop (symlink to $out)
    #    * gsettings
    # 2. Development/build tools ($dev)
    #    * gdbus-codegen
    #    * gio-querymodules
    #    * glib-compile-resources
    #    * glib-compile-schemas
    #    * glib-genmarshal
    #    * glib-gettextize
    #    * glib-mkenums
    #    * gobject-query
    #    * gresource
    #    * gtester
    #    * gtester-report
    # 3. Tools for desktop environment that cannot go to $bin due to $out depending on them ($out)
    #    * gio-launch-desktop
    ./split-dev-programs.patch
  ] ++ optional doCheck ./skip-timer-test.patch;

  outputs = [ "bin" "out" "dev" "devdoc" ];

  setupHook = ./setup-hook.sh;

  buildInputs = [
    libelf setupHook pcre
    bash gnum4 # install glib-gettextize and m4 macros for other apps to use
    gtk-doc
  ] ++ optionals stdenv.isLinux [
    libselinux
    util-linuxMinimal # for libmount
  ] ++ optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
    AppKit Carbon Cocoa CoreFoundation CoreServices Foundation
  ]);

  strictDeps = true;

  nativeBuildInputs = [
    meson ninja pkg-config perl python3 gettext gtk-doc docbook_xsl docbook_xml_dtd_45 libxml2
  ];

  propagatedBuildInputs = [ zlib libffi gettext libiconv ];

  mesonFlags = [
    # Avoid the need for gobject introspection binaries in PATH in cross-compiling case.
    # Instead we just copy them over from the native output.
    "-Dgtk_doc=${boolToString (stdenv.hostPlatform == stdenv.buildPlatform)}"
    "-Dnls=enabled"
    "-Ddevbindir=${placeholder "dev"}/bin"
  ];

  NIX_CFLAGS_COMPILE = toString [
    "-Wno-error=nonnull"
    # Default for release buildtype but passed manually because
    # we're using plain
    "-DG_DISABLE_CAST_CHECKS"
  ];

  hardeningDisable = [ "pie" ];

  postPatch = ''
    chmod +x gio/tests/gengiotypefuncs.py
    patchShebangs gio/tests/gengiotypefuncs.py
    chmod +x docs/reference/gio/concat-files-helper.py
    patchShebangs docs/reference/gio/concat-files-helper.py
    patchShebangs glib/gen-unicode-tables.pl
    patchShebangs tests/gen-casefold-txt.py
    patchShebangs tests/gen-casemap-txt.py
  '';

  DETERMINISTIC_BUILD = 1;

  postInstall = ''
    moveToOutput "share/glib-2.0" "$dev"
    substituteInPlace "$dev/bin/gdbus-codegen" --replace "$out" "$dev"
    sed -i "$dev/bin/glib-gettextize" -e "s|^gettext_dir=.*|gettext_dir=$dev/share/glib-2.0/gettext|"

    # This file is *included* in gtk3 and would introduce runtime reference via __FILE__.
    sed '1i#line 1 "${pname}-${version}/include/glib-2.0/gobject/gobjectnotifyqueue.c"' \
      -i "$dev"/include/glib-2.0/gobject/gobjectnotifyqueue.c
  '' + optionalString (stdenv.hostPlatform != stdenv.buildPlatform) ''
    cp -r ${buildPackages.glib.devdoc} $devdoc
  '';

  checkInputs = [ tzdata desktop-file-utils shared-mime-info ];

  preCheck = optionalString doCheck ''
    export LD_LIBRARY_PATH="$NIX_BUILD_TOP/${pname}-${version}/glib/.libs''${LD_LIBRARY_PATH:+:}$LD_LIBRARY_PATH"
    export TZDIR="${tzdata}/share/zoneinfo"
    export XDG_CACHE_HOME="$TMP"
    export XDG_RUNTIME_HOME="$TMP"
    export HOME="$TMP"
    export XDG_DATA_DIRS="${desktop-file-utils}/share:${shared-mime-info}/share"
    export G_TEST_DBUS_DAEMON="${dbus.daemon}/bin/dbus-daemon"
    export PATH="$PATH:$(pwd)/gobject"
    echo "PATH=$PATH"

    substituteInPlace gio/tests/desktop-files/home/applications/epiphany-weather-for-toronto-island-9c6a4e022b17686306243dada811d550d25eb1fb.desktop \
      --replace "Exec=/bin/true" "Exec=${coreutils}/bin/true"
    # Needs machine-id, comment the test
    sed -e '/\/gdbus\/codegen-peer-to-peer/ s/^\/*/\/\//' -i gio/tests/gdbus-peer.c
    sed -e '/g_test_add_func/ s/^\/*/\/\//' -i gio/tests/gdbus-unix-addresses.c
    # All gschemas fail to pass the test, upstream bug?
    sed -e '/g_test_add_data_func/ s/^\/*/\/\//' -i gio/tests/gschema-compile.c
    # Cannot reproduce the failing test_associations on hydra
    sed -e '/\/appinfo\/associations/d' -i gio/tests/appinfo.c
    # Needed because of libtool wrappers
    sed -e '/g_subprocess_launcher_set_environ (launcher, envp);/a g_subprocess_launcher_setenv (launcher, "PATH", g_getenv("PATH"), TRUE);' -i gio/tests/gsubprocess.c
  '';

  inherit doCheck;

  separateDebugInfo = stdenv.isLinux;

  passthru = rec {
    gioModuleDir = "lib/gio/modules";
    makeSchemaPath = dir: name: "${dir}/share/gsettings-schemas/${name}/glib-2.0/schemas";
    getSchemaPath = pkg: makeSchemaPath pkg pkg.name;
    inherit flattenInclude;
    updateScript = gnome3.updateScript { packageName = "glib"; };
  };

  meta = with lib; {
    description = "C library of programming buildings blocks";
    homepage    = "https://www.gtk.org/";
    license     = licenses.lgpl21Plus;
    maintainers = with maintainers; [ lovek323 raskin worldofpeace ];
    platforms   = platforms.unix;

    longDescription = ''
      GLib provides the core application building blocks for libraries
      and applications written in C.  It provides the core object
      system used in GNOME, the main loop implementation, and a large
      set of utility functions for strings and common data structures.
    '';
  };
}
