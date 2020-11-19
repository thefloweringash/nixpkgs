{ stdenv, fetchFromGitHub, pkg-config, cmake, openssl, cli11 }:

let
  inherit (stdenv) lib;
in

stdenv.mkDerivation {
  name = "sigtool";

  src = fetchFromGitHub {
    owner = "thefloweringash";
    repo = "sigtool";
    rev = "6b5cae59b97b06f69972d5920563f8e03210f6f4";
    sha256 = "1vai3gfnphs53i8rji19vwk3792jxz5147h534vq1dkfz4a60kn2";
  };

  nativeBuildInputs = [ pkg-config cmake ];
  buildInputs = [ openssl cli11 ];

  installPhase = ''
    mkdir -p $out/bin
    cp gensig $out/bin
  '';
}
