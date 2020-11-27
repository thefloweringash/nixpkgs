{ stdenv, fetchFromGitHub, pkg-config, cmake, openssl, cli11 }:

let
  inherit (stdenv) lib;
in

stdenv.mkDerivation {
  name = "sigtool";

  src = fetchFromGitHub {
    owner = "thefloweringash";
    repo = "sigtool";
    rev = "1dafd2ca4651210ba9acce10d279ace22b50fb01";
    sha256 = "1kcml7n6rsxvgkg6xj8h272ray5x7zpz091k6p5mzcmg74i9x94p";
  };

  nativeBuildInputs = [ pkg-config cmake ];
  buildInputs = [ openssl cli11 ];

  # This is a cmake build, so PWD is not the source.
  # Upstream (me) asserts the driver script is optional.
  postInstall = ''
    cp $NIX_BUILD_TOP/$sourceRoot/codesign.sh $out/bin/codesign
  '';
}
