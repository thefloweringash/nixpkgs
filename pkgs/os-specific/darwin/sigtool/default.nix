{ stdenv, fetchFromGitHub, pkg-config, cmake, cryptopp, cli11 }:

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

  installPhase = ''
    mkdir -p $out/bin
    cp gensig $out/bin
  '';
}
