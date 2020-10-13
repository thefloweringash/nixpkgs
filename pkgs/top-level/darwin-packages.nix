{ lib, buildPackages, pkgs, targetPackages, writeTextFile
, darwin, stdenv, callPackage, callPackages, newScope
, makeSetupHook, CFCrossStdenv
}:

let
  # Open source packages that are built from source
  appleSourcePackages = callPackage ../os-specific/darwin/apple-source-releases {};

  # macOS 11.0 / 10.16 SDK (TODO: fix naming)
  new_apple_sdk = callPackage ../os-specific/darwin/macosx-sdk { };

  # macOS 10.12 SDK
  old_apple_sdk = callPackage ../os-specific/darwin/apple-sdk {
    inherit (darwin) darwin-stubs print-reexports;
  };

  apple_sdk = if stdenv.hostPlatform.isAarch64 then new_apple_sdk else old_apple_sdk;

  chooseLibs = {
    inherit (
      if stdenv.hostPlatform.isAarch64
        then new_apple_sdk
        else appleSourcePackages
    ) Libsystem LibsystemCross libcharset libunwind objc4 ICU configd IOKit;
  };
in

(appleSourcePackages // chooseLibs // {

  inherit apple_sdk;

  callPackage = newScope (darwin.apple_sdk.frameworks // darwin);

  stdenvNoCF = stdenv.override {
    extraBuildInputs = [];
  };

  binutils-unwrapped = callPackage ../os-specific/darwin/binutils {
    inherit (darwin) cctools;
    inherit (pkgs) binutils-unwrapped;
    inherit (pkgs.llvmPackages_7) llvm;
  };

  binutils = pkgs.wrapBintoolsWith {
    libc = (x: builtins.trace ("darwin (target=${stdenv.targetPlatform.config}) setting binutils.libc=${x}") x) (

      if stdenv.targetPlatform.isAarch64 && (stdenv.buildPlatform != stdenv.targetPlatform)
      then new_apple_sdk.Libsystem
      else pkgs.stdenv.cc.libc

      ## TODO: this looks correct but goes into infinite recursing territory
      ## if stdenv.targetPlatform != stdenv.hostPlatform
      ## then pkgs.libcCross
      ## else pkgs.stdenv.cc.libc
    );
    bintools = darwin.binutils-unwrapped;
    extraPackages = [ darwin.sigtool ];
    extraBuildCommands = ''
      echo 'source ${darwin.postLinkSignHook}' >> $out/nix-support/post-link-hook
    '';
  };

  cctools = callPackage ../os-specific/darwin/cctools/port.nix {
    inherit (darwin) libobjc maloader libtapi;
    stdenv = if stdenv.isDarwin then stdenv else pkgs.libcxxStdenv;
  };

  # TODO: remove alias.
  cf-private = darwin.apple_sdk.frameworks.CoreFoundation;

  DarwinTools = callPackage ../os-specific/darwin/DarwinTools { };

  darwin-stubs = callPackage ../os-specific/darwin/darwin-stubs { };

  print-reexports = callPackage ../os-specific/darwin/print-reexports { };

  sigtool = callPackage ../os-specific/darwin/sigtool { };

  autoSignDarwinBinariesHook = makeSetupHook {
    substitutions = { inherit (darwin.binutils) targetPrefix; };
    deps = [ darwin.sigtool ];
  } ../os-specific/darwin/sigtool/setup-hook.sh;

  # TODO: overlaps a lot with the sigtool setup hook
  postLinkSignHook = writeTextFile {
    name = "post-link-sign-hook";
    executable = true;
    text = ''
      signDarwinBinary() {
        local path="$1"
        local sigsize arch

        arch=$(gensig --file "$path" show-arch)

        sigsize=$(gensig --file "$path" size)
        sigsize=$(( ((sigsize + 15) / 16) * 16 + 1024 ))

        ${darwin.binutils.targetPrefix}codesign_allocate -i "$path" -a "$arch" "$sigsize" -o "$path.unsigned"
        gensig --identifier "$(basename "$path")" --file "$path.unsigned" inject
        mv -f "$path.unsigned" "$path"
      }

      signDarwinBinary "$linkerOutput"
    '';
  };

  checkReexportsHook = makeSetupHook {
    deps = [ pkgs.darwin.print-reexports ];
  } ../os-specific/darwin/print-reexports/setup-hook.sh;

  maloader = callPackage ../os-specific/darwin/maloader {
    inherit (darwin) opencflite;
  };

  insert_dylib = callPackage ../os-specific/darwin/insert_dylib { };

  iosSdkPkgs = darwin.callPackage ../os-specific/darwin/xcode/sdk-pkgs.nix {
    buildIosSdk = buildPackages.darwin.iosSdkPkgs.sdk;
    targetIosSdkPkgs = targetPackages.darwin.iosSdkPkgs;
    xcode = darwin.xcode;
    inherit (pkgs.llvmPackages) clang-unwrapped;
  };

  iproute2mac = callPackage ../os-specific/darwin/iproute2mac { };

  libobjc = pkgs.darwin.objc4;

  lsusb = callPackage ../os-specific/darwin/lsusb { };

  opencflite = callPackage ../os-specific/darwin/opencflite { };

  stubs = callPackages ../os-specific/darwin/stubs { };

  trash = darwin.callPackage ../os-specific/darwin/trash { };

  usr-include = callPackage ../os-specific/darwin/usr-include { };

  inherit (callPackages ../os-specific/darwin/xcode { })
    xcode_8_1 xcode_8_2
    xcode_9_1 xcode_9_2 xcode_9_4 xcode_9_4_1
    xcode_10_2 xcode_10_2_1 xcode_10_3
    xcode_11
    xcode;

  CoreSymbolication = callPackage ../os-specific/darwin/CoreSymbolication { };

  CF = callPackage ../os-specific/darwin/swift-corelibs/corefoundation.nix { inherit (darwin) objc4 ICU; };

  # this is really a pain
  # - we want our stdenv to contain CF.
  # - non-cross does this in a bootstrap phase.
  # - adding extra phases to cross messes up package adjacencies.
  # => we define a "CF" package that does not depend on stdenv directly,
  #    but everything in the dependency tree uses CFCrossStdenv or CFCrossStdenvNoCC, which
  #    are simple aliases to remove extraBuildInputs.
  # TODO: find a better way
  #  - it's likely safe to say that all stdenvNoCC variants never require extraBuildInputs
  #  - so replace CFCrossStdenvNoCC with stdenvNoCC
  #  - which just leaves libxml2, zlib and curl
  # CFCross = pkgs.darwin.CFCrossPkgs.hello;
  CFCross = pkgs.darwin.CFCrossPkgs.CF;

  CFCrossPkgs = let
    packages = rec {
      hello = pkgs.hello.override {
        stdenv = CFCrossStdenv;
      };

      libxml2 = pkgs.libxml2.override {
        stdenv = pkgs.CFCrossStdenv;
        pythonSupport = false;
        icuSupport = false;
        zlib = pkgs.zlib.override {
          stdenv = pkgs.CFCrossStdenv;
        };
      };

      curl = pkgs.curl.override {
        stdenv = pkgs.CFCrossStdenv;
        http2Support = false;
        idnSupport = false;
        ldapSupport = false;
        zlibSupport = false;
        sslSupport = false;
        gnutlsSupport = false;
        scpSupport = false;
        gssSupport = false;
        c-aresSupport = false;
        brotliSupport = false;
      };

      CF = pkgs.darwin.CF.override {
        stdenv = pkgs.CFCrossStdenv;
        inherit libxml2 curl;
      };
    };
  in packages;

  # As the name says, this is broken, but I don't want to lose it since it's a direction we want to go in
  # libdispatch-broken = callPackage ../os-specific/darwin/swift-corelibs/libdispatch.nix { inherit (darwin) apple_sdk_sierra xnu; };

  darling = callPackage ../os-specific/darwin/darling/default.nix { };

  libtapi = callPackage ../os-specific/darwin/libtapi {
    inherit (pkgs.darwin.cctools) stdenv;
  };

  ios-deploy = callPackage ../os-specific/darwin/ios-deploy {};

  discrete-scroll = callPackage ../os-specific/darwin/discrete-scroll {
    inherit (darwin.apple_sdk.frameworks) Cocoa;
  };

})
