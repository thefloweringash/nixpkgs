{ stdenv, fetchFromGitHub, fetchpatch }:

let
  version = "2.9.4";
in stdenv.mkDerivation {
  pname = "http-parser";
  inherit version;

  src = fetchFromGitHub {
    owner = "nodejs";
    repo = "http-parser";
    rev = "v${version}";
    sha256 = "1vda4dp75pjf5fcph73sy0ifm3xrssrmf927qd1x8g3q46z0cv6c";
  };

  NIX_CFLAGS_COMPILE = "-Wno-error";
  patches = [
    ./build-shared.patch

    # Fixes tests on 32-bit platforms
    # https://github.com/nodejs/http-parser/pull/510
    (fetchpatch {
      url = "https://github.com/nodejs/http-parser/commit/0e5868aebb9eb92b078d27bb2774c2154dc167e2.patch";
      sha256 = "0jpg1v1wy7pz9sx0pmvcs1498bhk0dsprbw5fnis6k9nshlg54n5";
    })
  ];
  makeFlags = [ "DESTDIR=" "PREFIX=$(out)" ];
  buildFlags = [ "library" ];
  doCheck = true;
  checkTarget = "test";

  meta = with stdenv.lib; {
    description = "An HTTP message parser written in C";
    homepage = "https://github.com/nodejs/http-parser";
    maintainers = with maintainers; [ matthewbauer ];
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
