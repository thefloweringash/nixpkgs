{ appleDerivation, stdenvNoCC }:

let
  appleDerivation_ = appleDerivation.override {
    stdenv = stdenvNoCC;
  };
in

appleDerivation_ {
  installPhase = ''
    mkdir -p $out/include
    cp *.h $out/include/
  '';
}
