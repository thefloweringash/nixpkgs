{ stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation {
  pname = "darwin-stubs";
  version = "10.12";

  src = fetchFromGitHub {
    owner = "NixOS";
    repo = "darwin-stubs";
    rev = "7f4a8a085e4bc17a15ff62d2e0683b92d0c61396";
    sha256 = "11gakp70k10d5zbskbkjnxq5v9gdanvp8ivvpzgvmgl6mgfrpxhd";
  };

  dontBuild = true;

  installPhase = ''
    mkdir $out
    cp -vr stubs/$version/* $out
  '';
}
