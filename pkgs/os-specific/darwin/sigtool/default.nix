{ stdenv, fetchFromGitHub, pkg-config, cmake, cryptopp, cli11 }:

stdenv.mkDerivation {
  name = "sigtool";

  src = fetchFromGitHub {
    owner = "thefloweringash";
    repo = "sigtool";
    rev = "262e5071f16d12d706eb86e7d627cc37e7c6e1b7";
    sha256 = "05qnkzh8rxplk59jrv48rcdlqpk75p8j3kk0f2gmkjvfmi184qpy";
  };

  nativeBuildInputs = [ pkg-config cmake ];
  buildInputs = [ cryptopp cli11 ];

  installPhase = ''
    mkdir -p $out/bin
    cp gensig $out/bin
  '';
}
