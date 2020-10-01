{ appleDerivation, stdenvNoCC }:

let
  appleDerivation_ = appleDerivation.override {
    stdenv = stdenvNoCC;
  };
in

appleDerivation_ {
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/include/
    cp copyfile.h $out/include/
  '';
}
