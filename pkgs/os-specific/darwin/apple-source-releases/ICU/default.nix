{ appleDerivation, name, version, stdenv, buildRoot ? false }:

appleDerivation {
  name = "${name}${stdenv.lib.optionalString buildRoot "-build-root"}-${version}";
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

  installPhase = if buildRoot then ''
    mkdir $out
    mv * $out
  '' else null;

  postInstall = stdenv.lib.optionalString (!buildRoot) ''
    mv $out/usr/local/include $out/include
    rm -rf $out/usr
  '';
}
