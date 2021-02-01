{ lib, stdenv
, buildPackages
, fetch
, cmake
, libxml2
, llvm
, version
}:

stdenv.mkDerivation rec {
  pname = "lld";
  inherit version;

  src = fetch pname "1kk61i7z5bi9i11rzsd2b388d42if1c7a45zkaa4mk0yps67hyh1";

  nativeBuildInputs = [ cmake ];
  buildInputs = [ llvm libxml2 ];

  cmakeFlags = lib.optionals (stdenv.hostPlatform != stdenv.buildPlatform) [
    "-DLLVM_TABLEGEN_EXE=${buildPackages.llvm_11}/bin/llvm-tblgen"
    "-DLLVM_CONFIG_PATH=${llvm}/bin/llvm-config-native"
  ];

  outputs = [ "out" "dev" ];

  postInstall = ''
    moveToOutput include "$dev"
    moveToOutput lib "$dev"
  '';

  meta = {
    description = "The LLVM Linker";
    homepage    = "https://lld.llvm.org/";
    license     = lib.licenses.ncsa;
    platforms   = lib.platforms.all;
  };
}
