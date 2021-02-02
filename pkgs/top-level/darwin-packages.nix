{ lib, buildPackages, pkgs, targetPackages, writeTextFile
, darwin, stdenv, callPackage, callPackages, newScope
, makeSetupHook
}:

let
  # Open source packages that are built from source
  appleSourcePackages = callPackage ../os-specific/darwin/apple-source-releases {};

  impure-cmds = callPackage ../os-specific/darwin/impure-cmds { };

  # macOS 11.0 SDK
  apple_sdk_11_0 = callPackage ../os-specific/darwin/apple-sdk-11.0 { };

  # macOS 10.12 SDK
  apple_sdk_10_12 = callPackage ../os-specific/darwin/apple-sdk {
    inherit (darwin) darwin-stubs print-reexports;
  };

  # Pick an SDK
  apple_sdk = if stdenv.hostPlatform.isAarch64 then apple_sdk_11_0 else apple_sdk_10_12;

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

  llvmPackages = if stdenv.targetPlatform.isAarch64 then pkgs.llvmPackages_11 else pkgs.llvmPackages_7;
in

(impure-cmds // appleSourcePackages // chooseLibs // {

  inherit apple_sdk;

  callPackage = newScope (darwin.apple_sdk.frameworks // darwin);

  stdenvNoCF = stdenv.override {
    extraBuildInputs = [];
  };

  binutils-unwrapped = callPackage ../os-specific/darwin/binutils {
    inherit (darwin) cctools;
    inherit (pkgs) binutils-unwrapped;
    inherit (llvmPackages) llvm clang-unwrapped;
  };

  binutils = pkgs.wrapBintoolsWith {
    ## TODO: this looks correct but goes into infinite recursing territory
    ## if stdenv.targetPlatform != stdenv.hostPlatform
    ## then pkgs.libcCross
    ## else pkgs.stdenv.cc.libc
    libc =
      if stdenv.targetPlatform.isAarch64 && (stdenv.buildPlatform != stdenv.targetPlatform)
      then apple_sdk_11_0.Libsystem
      else pkgs.stdenv.cc.libc;
    bintools = darwin.binutils-unwrapped;
    inherit (darwin) postLinkSignHook signingUtils;
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

  checkReexportsHook = makeSetupHook {
    deps = [ pkgs.darwin.print-reexports ];
  } ../os-specific/darwin/print-reexports/setup-hook.sh;

  sigtool = callPackage ../os-specific/darwin/sigtool { };

  postLinkSignHook = writeTextFile {
    name = "post-link-sign-hook";
    executable = true;

    text = ''
      CODESIGN_ALLOCATE=${darwin.binutils.targetPrefix}codesign_allocate \
        ${darwin.sigtool}/bin/codesign -f -s - "$linkerOutput"
    '';
  };

  signingUtils = callPackage ../os-specific/darwin/signing-utils {
    inherit (darwin) cctools sigtool;
  };

  autoSignDarwinBinariesHook = makeSetupHook {
    deps = [ darwin.signingUtils ];
  } ../os-specific/darwin/signing-utils/auto-sign-hook.sh;

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

  # TODO: make swift-corefoundation build with apple_sdk_11_0.Libsystem
  CF = if useAppleSDKLibs
    then
      # This attribute (CF) is included in extraBuildInputs in the stdenv. This
      # is typically the open source project. When a project refers to
      # "CoreFoundation" it has an extra setup hook to force impure system
      # CoreFoundation into the link step.
      #
      # In this branch, we only have a single "CoreFoundation" to choose from.
      # To be compatible with the existing convention, we define
      # CoreFoundation with the setup hook, and CF as the same package but
      # with the setup hook removed.
      #
      # This may seem unimportant, but without it packages (e.g., bacula) will
      # fail with linker errors referring ___CFConstantStringClassReference.
      # It's not clear to me why some packages need this extra setup.
      lib.overrideDerivation apple_sdk.frameworks.CoreFoundation (drv: {
        setupHook = null;
      })
    else callPackage ../os-specific/darwin/swift-corelibs/corefoundation.nix { inherit (darwin) objc4 ICU; };

  # As the name says, this is broken, but I don't want to lose it since it's a direction we want to go in
  # libdispatch-broken = callPackage ../os-specific/darwin/swift-corelibs/libdispatch.nix { inherit (darwin) apple_sdk_sierra xnu; };

  darling = callPackage ../os-specific/darwin/darling/default.nix { };

  libtapi = callPackage ../os-specific/darwin/libtapi {};

  ios-deploy = callPackage ../os-specific/darwin/ios-deploy {};

  discrete-scroll = callPackage ../os-specific/darwin/discrete-scroll {
    inherit (darwin.apple_sdk.frameworks) Cocoa;
  };

})
