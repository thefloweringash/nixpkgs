{ stdenv, stdenvNoCC, appleDerivation }:

let
  appleDerivation_ = appleDerivation.override {
    stdenv = stdenvNoCC;
  };
in

appleDerivation_ {
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/include
    cp MacTypes.h           $out/include
    cp ConditionalMacros.h  $out/include
    cp TargetConditionals.h $out/include

    substituteInPlace $out/include/MacTypes.h \
      --replace "CarbonCore/" ""
  '';

  meta = with stdenv.lib; {
    maintainers = with maintainers; [ copumpkin ];
    platforms   = platforms.darwin;
    license     = licenses.apsl20;
  };
}
