{ appleDerivation, stdenvNoCC }:

let
  appleDerivation_ = appleDerivation.override {
    stdenv = stdenvNoCC;
  };
in

appleDerivation_ {
  phases = [ "unpackPhase" "installPhase" ];

  installPhase = ''
    mkdir -p $out/include
    cp mDNSShared/dns_sd.h $out/include
  '';
}
