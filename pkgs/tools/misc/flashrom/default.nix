{ lib
, stdenv
, fetchurl
, meson
, ninja
, pkgconfig
, libftdi1
, libusb1
, pciutils
}:

stdenv.mkDerivation rec {
  pname = "flashrom";
  version = "1.2";

  src = fetchurl {
    url = "https://download.flashrom.org/releases/flashrom-v${version}.tar.bz2";
    sha256 = "0ax4kqnh7kd3z120ypgp73qy1knz47l6qxsqzrfkd97mh5cdky71";
  };

  nativeBuildInputs = [ meson pkgconfig ninja ];
  buildInputs = [ libftdi1 libusb1 ] ++ stdenv.lib.optional (! stdenv.isDarwin) pciutils;

  mesonFlags = [
    "-Dpciutils=${lib.boolToString stdenv.isLinux}"
    "-Dconfig_linux_mtd=${lib.boolToString stdenv.isLinux}"
    "-Dconfig_linux_spi=${lib.boolToString stdenv.isLinux}"

    # TODO: when are these to be disabled?
    "-Dconfig_serprog=false"
    "-Dconfig_buspirate_spi=false"
    "-Dconfig_pony_spi=false"
    "-Dconfig_developerbox_spi=false"
  ];

  patches = [ ./fixes.patch ];

  meta = with lib; {
    homepage = http://www.flashrom.org;
    description = "Utility for reading, writing, erasing and verifying flash ROM chips";
    license = licenses.gpl2;
    maintainers = with maintainers; [ funfunctor fpletz ];
    platforms = platforms.all;
    # https://github.com/flashrom/flashrom/issues/125
    badPlatforms = [ "aarch64-linux" ];
  };
}
