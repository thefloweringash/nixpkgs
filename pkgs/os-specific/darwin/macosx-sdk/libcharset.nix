{ stdenvNoCC, MacOSX-SDK, libcharset }:

stdenvNoCC.mkDerivation {
  pname = "libcharset";
  version = MacOSX-SDK.version;

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/{include,lib}
    cp ${MacOSX-SDK}/usr/lib/libcharset* $out/lib
  '';
}
