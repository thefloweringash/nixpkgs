{ appleDerivation, stdenv, buildPackages }:

appleDerivation {
  patches = [ ./clang-5.patch ];

  depsBuildBuild = [ buildPackages.stdenv.cc ];

  postPatch = ''
    substituteInPlace makefile \
      --replace /usr/bin/ "" \
      --replace '$(ISYSROOT)' "" \
      --replace 'shell xcodebuild -version -sdk' 'shell true' \
      --replace 'shell xcrun -sdk $(SDKPATH) -find' 'shell echo' \
      --replace '-install_name $(libdir)' "-install_name $out/lib/" \
      --replace /usr/local/bin/ /bin/ \
      --replace /usr/lib/ /lib/ \
  '' + stdenv.lib.optionalString (stdenv.buildPlatform != stdenv.hostPlatform) ''

    # This looks like a bug in the makefile. It defines ENV_BUILDHOST to
    # propagate the correct value of CC, CXX, etc, but has the following double
    # expansion that results in the empty string.
    substituteInPlace makefile \
      --replace '$($(ENV_BUILDHOST))' '$(ENV_BUILDHOST)'
  '';

  makeFlags = [ "DSTROOT=$(out)" ]
    ++ stdenv.lib.optionals (stdenv.buildPlatform != stdenv.hostPlatform) [
      "CROSS_BUILD=YES"
      "BUILD_TYPE="
      "RC_ARCHS=${stdenv.hostPlatform.darwinArch}"
      "HOSTCC=cc"
      "HOSTCXX=c++"
      "CC=${stdenv.cc.targetPrefix}cc"
      "CXX=${stdenv.cc.targetPrefix}c++"
      "HOSTISYSROOT="
    ];

  postInstall = ''
    mv $out/usr/local/include $out/include
    rm -rf $out/usr
  '';
}
