{ stdenv, fetchFromGitHub, pkg-config, cmake, openssl, cli11 }:

let
  inherit (stdenv) lib;
in

stdenv.mkDerivation {
  name = "sigtool";

  src = fetchFromGitHub {
    owner = "thefloweringash";
    repo = "sigtool";
    rev = "eb21a915936168f669e0c1c2170af34af4201bc2";
    sha256 = "011248fm9rgm5b2jja9ngb9kic0mpm8pphipjybnfwblzdfvcjl8";
  };

  nativeBuildInputs = [ pkg-config cmake ];
  buildInputs = [ openssl cli11 ];

  installPhase = ''
    mkdir -p $out/bin
    cp gensig $out/bin
  '';
}
