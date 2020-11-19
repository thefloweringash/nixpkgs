{ stdenv, fetchFromGitHub, cmake, pkg-config, libyaml }:

stdenv.mkDerivation {
  pname = "rewrite-tbd";
  version = "20201114";

  src = fetchFromGitHub {
    owner = "thefloweringash";
    repo = "rewrite-tbd";
    rev = "688b77bdfed06be0784b56b5515e78c2e5a262fd";
    sha256 = "0c52fhnb30d0h6v4q192dkk0m8xiwnc9cvrxjji3chxp274yp1k3";
  };

  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ libyaml ];
}
