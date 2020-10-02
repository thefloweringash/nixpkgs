{ stdenvNoCC, MacOSX-SDK, libcharset }:

stdenvNoCC.mkDerivation {
  pname = "libiconv";
  version = MacOSX-SDK.version;

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/{include,lib}
    cp ${MacOSX-SDK}/usr/lib/libiconv*   $out/lib
    cp ${MacOSX-SDK}/usr/include/iconv.h $out/include
  '';
}

