{ appleDerivation, lib, stdenv, stdenvNoCC, headersOnly ? false }:

let
  appleDerivation_ = appleDerivation.override {
    stdenv = if headersOnly then stdenvNoCC else stdenv;
  };
in

appleDerivation_ {
  installPhase = lib.optionalString headersOnly ''
    mkdir -p $out/include/hfs
    cp core/*.h $out/include/hfs
  '';
}
