{ stdenvNoCC, buildPackages, MacOSX-SDK }:

stdenvNoCC.mkDerivation {
  pname = "libnetwork";
  version = MacOSX-SDK.version;

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ buildPackages.darwin.checkReexportsHook ];

  installPhase = ''
    mkdir -p $out/lib
    cp ${MacOSX-SDK}/usr/lib/libnetwork* $out/lib
  '';
}
