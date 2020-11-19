{ CFCrossStdenv, fetchurl, buildPackages, buildRoot ? false }:

let
  stdenv = CFCrossStdenv;
in
stdenv.mkDerivation rec {
  pname = "ICU${stdenv.lib.optionalString buildRoot "-build-root"}";
  version = "531.48";

  src = fetchurl {
    url = "http://www.opensource.apple.com/tarballs/${pname}/${pname}-${version}.tar.gz";
    sha256 = "1qihlp42n5g4dl0sn0f9pc0bkxy1452dxzf0vr6y5gqpshlzy03p";
  };

  # Using the regular configure script means less effort, but the resulting
  # build is a lot larger, possibly more complete?
  sourceRoot = "${pname}-${version}/icuSources";

  patches = [ ./clang-5.patch ];

  configureFlags = stdenv.lib.optionals (stdenv.hostPlatform != stdenv.buildPlatform) [
    "--with-cross-build=${buildPackages.darwin.ICU.override { buildRoot = true; }}/build"
  ];

  installPhase = if buildRoot then ''
    mkdir $out
    mv * $out
  '' else null;
}
