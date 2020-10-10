{ stdenv, fetchFromGitHub, pkg-config, cmake, cryptopp, cli11 }:

let
  inherit (stdenv) lib;
in

stdenv.mkDerivation {
  name = "sigtool";

  src = fetchFromGitHub {
    owner = "thefloweringash";
    repo = "sigtool";
    rev = "3c447d5ba14f912b76ac2c876d29a201377142fb";
    sha256 = "0000000000000000000000000000000000000000000000000000";
  };

  nativeBuildInputs = [ pkg-config cmake ];
  buildInputs = [ cryptopp cli11 ];

  installPhase = ''
    mkdir -p $out/bin
    cp gensig $out/bin
  '';
}
