{ stdenvNoCC, MacOSX-SDK, libcharset }:

stdenvNoCC.mkDerivation {
  pname = "libobjc";
  version = MacOSX-SDK.version;

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/{include,lib}
    cp -r ${MacOSX-SDK}/usr/include/objc $out/include
    cp ${MacOSX-SDK}/usr/lib/libobjc* $out/lib
  '';
}
