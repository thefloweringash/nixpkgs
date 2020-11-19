{ stdenvNoCC, appleDerivation }:

let
  appleDerivation_ = appleDerivation.override {
    stdenv = stdenvNoCC;
  };
in

appleDerivation_ {
  installPhase = ''
    mkdir -p $out/include

    cp Source/Intel/math.h $out/include
    cp Source/Intel/fenv.h $out/include
    cp Source/complex.h    $out/include
  '';
}
