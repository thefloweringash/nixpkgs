{ lib, buildPackages, pkgs, targetPackages, writeTextFile
, darwin, stdenv, callPackage, callPackages, newScope
, makeSetupHook
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

  # Pick an SDK
  apple_sdk = if stdenv.hostPlatform.isAarch64 then new_apple_sdk else old_apple_sdk;

  # Pick the source of libraries: either Apple's open source releases, or the
  # SDK.
  useAppleSDKLibs = stdenv.hostPlatform.isAarch64;

  chooseLibs = {
    inherit (
      if useAppleSDKLibs
        then apple_sdk
        else appleSourcePackages
    ) Libsystem LibsystemCross libcharset libunwind objc4 configd IOKit;

    inherit (
      if useAppleSDKLibs
        then apple_sdk.frameworks
        else appleSourcePackages
    ) Security;
  };

  llvmPackages = if stdenv.hostPlatform.isAarch64 then pkgs.llvmPackages_10 else pkgs.llvmPackages_7;
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
    inherit (llvmPackages) llvm;
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
    # TODO: make these only stdenv.targetPlatform.isAarch64
    # but without infinite recursion
    extraPackages = lib.optionals (stdenv.buildPlatform == stdenv.targetPlatform && stdenv.targetPlatform.isAarch64) [ darwin.sigtool ];
    extraBuildCommands = lib.optionalString (stdenv.buildPlatform == stdenv.targetPlatform && stdenv.targetPlatform.isAarch64) ''
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

  rewrite-tbd = callPackage ../os-specific/darwin/rewrite-tbd { };

  sigtool = callPackage ../os-specific/darwin/sigtool { };

  autoSignDarwinBinariesHook = makeSetupHook {
    substitutions = { inherit (pkgs.binutils-unwrapped) targetPrefix; };
    deps = [ darwin.sigtool ];
  } ../os-specific/darwin/sigtool/setup-hook.sh;

  postLinkSignHook = writeTextFile {
    name = "post-link-sign-hook";
    executable = true;

    # Ignores target prefix, assuming that post link signing is only required
    # on device, not cross compilation.
    text = ''
      if gensig --file "$linkerOutput" check-requires-signature; then
        codesign -f -s - "$linkerOutput"
      fi
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

  # TODO: make swift-corefoundation build with new_apple_sdk.Libsystem
  CF = if useAppleSDKLibs
    then apple_sdk.frameworks.CoreFoundation
    else callPackage ../os-specific/darwin/swift-corelibs/corefoundation.nix { inherit (darwin) objc4 ICU; };

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
