{ lib, stdenv, fetchurl, fetchpatch }:

let
  version = "2.13";
  name = "cpio-${version}";
in stdenv.mkDerivation {
  inherit name;

  src = fetchurl {
    url = "mirror://gnu/cpio/${name}.tar.bz2";
    sha256 = "0vbgnhkawdllgnkdn6zn1f56fczwk0518krakz2qbwhxmv2vvdga";
  };

  # Unreleased upstream patch fixing duplicate definition of program_name,
  # which may fail to link. Observed on aarch64-darwin.
  patches = fetchpatch {
    url = "https://git.savannah.gnu.org/cgit/cpio.git/patch/?id=641d3f489cf6238bb916368d4ba0d9325a235afb";
    sha256 = "1ffawzxjw72kzpdwffi2y7pvibrmwf4jzrxdq9f4a75q6crl66iq";
  };

  preConfigure = if stdenv.isCygwin then ''
    sed -i gnu/fpending.h -e 's,include <stdio_ext.h>,,'
  '' else null;

  enableParallelBuilding = true;

  meta = with lib; {
    homepage = "https://www.gnu.org/software/cpio/";
    description = "A program to create or extract from cpio archives";
    license = licenses.gpl3;
    platforms = platforms.all;
    priority = 6; # resolves collision with gnutar's "libexec/rmt"
  };
}
