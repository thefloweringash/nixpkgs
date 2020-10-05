{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "ICU";
  version = "531.48";

  src = fetchurl {
    url = "http://www.opensource.apple.com/tarballs/${pname}/${pname}-${version}.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000";
  };

  patches = [ ./clang-5.patch ];

  postPatch = ''
    substituteInPlace makefile \
      --replace /usr/bin/ "" \
      --replace '$(ISYSROOT)' "" \
      --replace 'shell xcodebuild -version -sdk' 'shell true' \
      --replace 'shell xcrun -sdk $(SDKPATH) -find' 'shell echo' \
      --replace '-install_name $(libdir)' "-install_name $out/lib/" \
      --replace /usr/local/bin/ /bin/ \
      --replace /usr/lib/ /lib/ \
  '';

  makeFlags = [ "DSTROOT=$(out)" ];

  postInstall = ''
    mv $out/usr/local/include $out/include
    rm -rf $out/usr
  '';
}
