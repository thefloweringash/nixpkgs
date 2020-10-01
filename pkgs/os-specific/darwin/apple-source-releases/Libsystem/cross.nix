{ stdenv, lib, stdenvNoCC, appleDerivation, name, version, Csu, libresolv, darwin-stubs, fetchurl }:

let
  appleDerivation_ = appleDerivation.override {
    stdenv = stdenvNoCC;
  };

  headers = fetchurl {
    url = "https://s3.ap-northeast-1.amazonaws.com/nix-misc.cons.org.nz/apple-silicon-wip/Libsystem-headers.tar.gz";
    sha256 = "11h4vg4zsws2kd3sy6xhfnzm0dc9gl5az0652csz2pf6axr111d6";
  };
in

appleDerivation_ {
  name = "${name}-cross-${version}";

  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    export NIX_ENFORCE_PURITY=

    mkdir -p $out/lib $out/include

    # Set up our include directories
    tar -C $out -xvf ${headers}

    cat <<EOF > $out/include/os/availability.h
    #ifndef __OS_AVAILABILITY__
    #define __OS_AVAILABILITY__
    #include <AvailabilityInternal.h>

    #if defined(__has_feature) && defined(__has_attribute) && __has_attribute(availability)
      #define API_AVAILABLE(...) __API_AVAILABLE_GET_MACRO(__VA_ARGS__, __API_AVAILABLE4, __API_AVAILABLE3, __API_AVAILABLE2, __API_AVAILABLE1)(__VA_ARGS__)
      #define API_DEPRECATED(...) __API_DEPRECATED_MSG_GET_MACRO(__VA_ARGS__, __API_DEPRECATED_MSG5, __API_DEPRECATED_MSG4, __API_DEPRECATED_MSG3, __API_DEPRECATED_MSG2, __API_DEPRECATED_MSG1)(__VA_ARGS__)
      #define API_DEPRECATED_WITH_REPLACEMENT(...) __API_DEPRECATED_REP_GET_MACRO(__VA_ARGS__, __API_DEPRECATED_REP5, __API_DEPRECATED_REP4, __API_DEPRECATED_REP3, __API_DEPRECATED_REP2, __API_DEPRECATED_REP1)(__VA_ARGS__)
      #define API_UNAVAILABLE(...) __API_UNAVAILABLE_GET_MACRO(__VA_ARGS__, __API_UNAVAILABLE3, __API_UNAVAILABLE2, __API_UNAVAILABLE1)(__VA_ARGS__)
    #else

      #define API_AVAILABLE(...)
      #define API_DEPRECATED(...)
      #define API_DEPRECATED_WITH_REPLACEMENT(...)
      #define API_UNAVAILABLE(...)

    #endif
    #endif
    EOF

    cat <<EOF > $out/include/TargetConditionals.h
    #ifndef __TARGETCONDITIONALS__
    #define __TARGETCONDITIONALS__
    #define TARGET_OS_MAC           1
    #define TARGET_OS_OSX           1
    #define TARGET_OS_WIN32         0
    #define TARGET_OS_UNIX          0
    #define TARGET_OS_EMBEDDED      0
    #define TARGET_OS_IPHONE        0
    #define TARGET_IPHONE_SIMULATOR 0
    #define TARGET_OS_LINUX         0

    #define TARGET_CPU_PPC          0
    #define TARGET_CPU_PPC64        0
    #define TARGET_CPU_68K          0
    #define TARGET_CPU_X86          0
    #define TARGET_CPU_X86_64       1
    #define TARGET_CPU_ARM          0
    #define TARGET_CPU_MIPS         0
    #define TARGET_CPU_SPARC        0
    #define TARGET_CPU_ALPHA        0
    #define TARGET_RT_MAC_CFM       0
    #define TARGET_RT_MAC_MACHO     1
    #define TARGET_RT_LITTLE_ENDIAN 1
    #define TARGET_RT_BIG_ENDIAN    0
    #define TARGET_RT_64_BIT        1
    #endif  /* __TARGETCONDITIONALS__ */
    EOF

    ${lib.optionalString (Csu != null) ''
      # The startup object files
      cp ${Csu}/lib/* $out/lib
    ''}

    cp -vr \
      ${darwin-stubs}/usr/lib/libSystem.B.tbd \
      ${darwin-stubs}/usr/lib/system \
      $out/lib

    substituteInPlace $out/lib/libSystem.B.tbd \
      --replace "/usr/lib/system/" "$out/lib/system/"
    ln -s libSystem.B.tbd $out/lib/libSystem.tbd

    # Set up links to pretend we work like a conventional unix (Apple's design, not mine!)
    for name in c dbm dl info m mx poll proc pthread rpcsvc util gcc_s.10.4 gcc_s.10.5; do
      ln -s libSystem.tbd $out/lib/lib$name.tbd
    done

    # This probably doesn't belong here, but we want to stay similar to glibc, which includes resolv internally...
    cp ${darwin-stubs}/usr/lib/libresolv.9.tbd $out/lib
    ln -s libresolv.9.tbd $out/lib/libresolv.tbd
  '';

  meta = with stdenv.lib; {
    description = "The Mac OS libc/libSystem (tapi library with pure headers)";
    maintainers = with maintainers; [ copumpkin gridaphobe ];
    platforms   = platforms.darwin;
    license     = licenses.apsl20;
  };
}
