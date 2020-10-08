{ stdenv, fetchFromGitHub, pkg-config, cmake, cryptopp, cli11 }:

let
  inherit (stdenv) lib;
in

stdenv.mkDerivation {
  name = "sigtool";

  src = fetchFromGitHub {
    owner = "thefloweringash";
    repo = "sigtool";
    rev = "5426e3918754bf5f771b1b7da6fc60181ba49ec2";
    sha256 = "171dlamli4clxgwj4shx92xywx13prbbhbsvsc1pyb2zdhq7sxr0";
  };

  nativeBuildInputs = [ pkg-config cmake ];
  buildInputs = [ cryptopp cli11 ];

  # TODO: push this and mass rebuild
  patches = lib.optionals (stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64) [
    ./deprecated-stat64.patch
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp gensig $out/bin
  '';
}
