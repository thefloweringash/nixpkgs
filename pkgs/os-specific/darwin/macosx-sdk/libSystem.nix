{ stdenvNoCC, MacOSX-SDK }:

stdenvNoCC.mkDerivation {
  pname = "libSystem";
  version = MacOSX-SDK.version;

  dontBuild = true;
  dontUnpack = true;

  includeDirs = [
    "CommonCrypto" "_types" "architecture" "arpa" "atm" "bank" "bsd" "bsm"
    "corecrypto" "corpses" "default_pager" "device" "dispatch" "hfs" "i386"
    "iokit" "kern" "libkern" "mach" "mach-o" "mach_debug" "machine" "malloc"
    "miscfs" "net" "netinet" "netinet6" "netkey" "nfs" "os" "osfmk" "pexpert"
    "platform" "protocols" "pthread" "rpc" "rpcsvc" "secure" "security"
    "servers" "sys" "uuid" "vfs" "voucher" "xlocale"
  ] ++ [
    "arm"
  ];

  csu = [
    "bundle1.o" "crt0.o" "crt1.10.5.o" "crt1.10.6.o" "crt1.o" "dylib1.10.5.o"
    "dylib1.o" "gcrt1.o" "lazydylib1.o"
  ];

  installPhase = ''
    mkdir -p $out/{include,lib}

    for dir in $includeDirs; do
      from=${MacOSX-SDK}/usr/include/$dir
      if [ -e "$from" ]; then
        cp -vr $from $out/include
      else
        echo "Header directory '$from' doesn't exist: skipping"
      fi
    done

    cp -vr \
      ${MacOSX-SDK}/usr/include/*.h \
      $out/include

    cp -vr \
      ${MacOSX-SDK}/usr/lib/libSystem.* \
      ${MacOSX-SDK}/usr/lib/system \
      $out/lib

    # Extra libraries
    for name in c dbm dl info m mx poll proc pthread rpcsvc util gcc_s.1; do
      cp ${MacOSX-SDK}/usr/lib/lib$name.tbd $out/lib
    done

    for f in $csu; do
      from=${MacOSX-SDK}/usr/lib/$f
      if [ -e "$from" ]; then
        cp -vr $from $out/lib
      else
        echo "Csu file '$from' doesn't exist: skipping"
      fi
    done

    find $out -name '*.tbd' | while read tbd; do
      substituteInPlace "$tbd" \
        --subst-var-by "Libsystem" "$out"
    done
  '';
}

