{ stdenvNoCC, appleDerivation }:

let
  appleDerivation_ = appleDerivation.override {
    stdenv = stdenvNoCC;
  };
in

appleDerivation_ {
  # No clue why the same file has two different names. Ask Apple!
  installPhase = ''
    mkdir -p $out/include/ $out/include/servers
    cp liblaunch/*.h $out/include

    cp liblaunch/bootstrap.h $out/include/servers
    cp liblaunch/bootstrap.h $out/include/servers/bootstrap_defs.h
  '';
}
