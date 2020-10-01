{ appleDerivation, stdenvNoCC }:

let
  appleDerivation_ = appleDerivation.override {
    stdenv = stdenvNoCC;
  };
in

appleDerivation_ {
  installPhase = ''
    mkdir $out
    cp -r include $out/include
  '';
}
