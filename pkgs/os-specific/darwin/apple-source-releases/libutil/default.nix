{ lib, appleDerivation, stdenv, stdenvNoCC, xcbuildHook

# headersOnly is true when building for libSystem
, headersOnly ? false }:

let
  appleDerivation_ = appleDerivation.override {
    stdenv = if headersOnly then stdenvNoCC else stdenv;
  };
in

appleDerivation_ {
  nativeBuildInputs = lib.optional (!headersOnly) xcbuildHook;

  prePatch = ''
    substituteInPlace tzlink.c \
      --replace '#include <xpc/xpc.h>' ""
  '';

  xcbuildFlags = [ "-target" "util" ];

  installPhase = ''
    mkdir -p $out/include
  '' + lib.optionalString headersOnly ''
    cp *.h $out/include
  '' + lib.optionalString (!headersOnly)''
    mkdir -p $out/lib $out/include

    cp Products/Release/*.dylib $out/lib
    cp Products/Release/*.h $out/include

    # TODO: figure out how to get this to be right the first time around
    install_name_tool -id $out/lib/libutil.dylib $out/lib/libutil.dylib
  '';

  meta = with lib; {
    maintainers = with maintainers; [ copumpkin ];
    platforms   = platforms.darwin;
    license     = licenses.apsl20;
  };
}
