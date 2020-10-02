{ stdenv, fetchurl, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "bsdmake";
  version = "24";

  src = fetchurl {
    url = "http://www.opensource.apple.com/tarballs/${pname}/${pname}-${version}.tar.gz";
    sha256 = "11a9kkhz5bfgi1i8kpdkis78lhc6b5vxmhd598fcdgra1jw4iac2";
  };

  nativeBuildInputs = [ makeWrapper ];

  patchPhase = ''
    substituteInPlace mk/bsd.prog.mk \
      --replace '-o ''${BINOWN} -g ''${BINGRP}' "" \
      --replace '-o ''${SCRIPTSOWN_''${.ALLSRC:T}}' "" \
      --replace '-g ''${SCRIPTSGRP_''${.ALLSRC:T}}' ""
    substituteInPlace mk/bsd.lib.mk --replace '-o ''${LIBOWN} -g ''${LIBGRP}' ""
    substituteInPlace mk/bsd.info.mk --replace '-o ''${INFOOWN} -g ''${INFOGRP}' ""
    substituteInPlace mk/bsd.doc.mk --replace '-o ''${BINOWN} -g ''${BINGRP}' ""
    substituteInPlace mk/bsd.man.mk --replace '-o ''${MANOWN} -g ''${MANGRP}' ""
    substituteInPlace mk/bsd.files.mk \
      --replace '-o ''${''${group}OWN_''${.ALLSRC:T}}' "" \
      --replace '-g ''${''${group}GRP_''${.ALLSRC:T}}' "" \
      --replace '-o ''${''${group}OWN} -g ''${''${group}GRP}' ""
    substituteInPlace mk/bsd.incs.mk \
      --replace '-o ''${''${group}OWN_''${.ALLSRC:T}}' "" \
      --replace '-g ''${''${group}GRP_''${.ALLSRC:T}}' "" \
      --replace '-o ''${''${group}OWN} -g ''${''${group}GRP}' ""
  '';

  buildPhase = ''
    objs=()
    for file in $(find . -name '*.c'); do
      obj="$(basename "$file" .c).o"
      objs+=("$obj")
      $CC -c "$file" -o "$obj" -DDEFSHELLNAME='"sh"' -D__FBSDID=__RCSID -mdynamic-no-pic -g
    done
    $CC "''${objs[@]}" -o bsdmake
  '';

  installPhase = ''
    install -d 0644 $out/bin
    install -m 0755 bsdmake $out/bin
    install -d 0644 $out/share/mk
    install -m 0755 mk/* $out/share/mk
  '';

  preFixup = ''
    wrapProgram "$out/bin/bsdmake" --add-flags "-m $out/share/mk"
  '';

  meta = {
    platforms = stdenv.lib.platforms.darwin;
  };
}
