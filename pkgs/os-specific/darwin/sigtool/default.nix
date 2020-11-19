{ lib, stdenv, fetchFromGitHub, pkg-config, cmake, makeWrapper, openssl, cli11 }:

stdenv.mkDerivation {
  name = "sigtool";

  src = fetchFromGitHub {
    owner = "thefloweringash";
    repo = "sigtool";
    rev = "429bc3bbe68d40606ac3ea447d93463a125daf5b";
    sha256 = "0fkszrilbmf1kiks9j092qzagwxclqv4y12yj8hxqpg6zy88fjj6";
  };

  nativeBuildInputs = [ pkg-config makeWrapper ];
  buildInputs = [ openssl ];

  installFlags = [ "PREFIX=$(out)" ];

  # Upstream (me) asserts the driver script is optional.
  postInstall = ''
    substitute $NIX_BUILD_TOP/$sourceRoot/codesign.sh $out/bin/codesign \
      --replace sigtool "$out/bin/sigtool"
    chmod a+x $out/bin/codesign
  '';
}
