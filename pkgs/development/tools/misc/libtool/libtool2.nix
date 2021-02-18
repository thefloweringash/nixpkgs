{ lib, stdenv, fetchurl, fetchpatch, autoconf, automake, m4, perl, help2man
}:

stdenv.mkDerivation rec {
  pname = "libtool";
  version = "2.4.6";

  src = fetchurl {
    url = "mirror://gnu/libtool/${pname}-${version}.tar.gz";
    sha256 = "1qq61k6lp1fp75xs398yzi6wvbx232l7xbyn3p13cnh27mflvgg3";
  };

  outputs = [ "out" "lib" ];

  patches = [
    # Suport macOS version 11.0
    # https://github.com/Homebrew/homebrew-core/blob/7195a32290968834b2435d9e7f00051ecb2d5371/Formula/libtool.rb#L20-L25
    # https://lists.gnu.org/archive/html/libtool-patches/2020-06/msg00001.html
    (fetchpatch {
      url = "https://raw.githubusercontent.com/Homebrew/formula-patches/e5fbd46a25e35663059296833568667c7b572d9a/libtool/dynamic_lookup-11.patch";
      includes = [ "m4/libtool.m4" ];
      extraPrefix = "";
      sha256 = "132vzm83pyqwh0dz1hbzcbavcns04qqd7dwapi1nzzpl8jgwcsli";
    })
  ];

  # Normally we'd use autoreconfHook, but that includes libtoolize.
  postPatch = ''
    aclocal -I m4
    automake
    autoconf

    pushd libltdl
    aclocal -I ../m4
    automake
    autoconf
    popd
  '';

  nativeBuildInputs = [ perl help2man m4 ] ++ [ autoconf automake ];
  propagatedBuildInputs = [ m4 ];

  # Don't fixup "#! /bin/sh" in Libtool, otherwise it will use the
  # "fixed" path in generated files!
  dontPatchShebangs = true;

  # XXX: The GNU ld wrapper does all sorts of nasty things wrt. RPATH, which
  # leads to the failure of a number of tests.
  doCheck = false;
  doInstallCheck = false;

  enableParallelBuilding = true;

  meta = with lib; {
    description = "GNU Libtool, a generic library support script";
    longDescription = ''
      GNU libtool is a generic library support script.  Libtool hides
      the complexity of using shared libraries behind a consistent,
      portable interface.

      To use libtool, add the new generic library building commands to
      your Makefile, Makefile.in, or Makefile.am.  See the
      documentation for details.
    '';
    homepage = "https://www.gnu.org/software/libtool/";
    license = licenses.gpl2Plus;
    maintainers = [ ];
    platforms = platforms.unix;
  };
}
