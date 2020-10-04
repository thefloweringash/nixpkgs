{ buildPackages, pkgs, targetPackages
, darwin, stdenv, callPackage, callPackages, newScope
, makeSetupHook
}:

let
  useAppleSDK = stdenv.hostPlatform.isAarch64;

  appleSourcePackages =
    callPackage ../os-specific/darwin/apple-source-releases {};

  appleSDK =
    callPackage ../os-specific/darwin/macosx-sdk {};

  sdkPackages = (builtins.trace "(${stdenv.buildPlatform.config}, ${stdenv.hostPlatform.config}, ${stdenv.targetPlatform.config}) -> useAppleSDK = ${builtins.toJSON useAppleSDK}") (
    if useAppleSDK then appleSDK else appleSourcePackages
  );
in

assert (stdenv.buildPlatform != stdenv.hostPlatform) -> useAppleSDK;

(sdkPackages // {

  callPackage = newScope (darwin.apple_sdk.frameworks // darwin);

  stdenvNoCF = stdenv.override {
    extraBuildInputs = [];
  };

  apple_sdk = if useAppleSDK then
    callPackage ../os-specific/darwin/macosx-sdk/apple_sdk.nix {
      inherit (darwin) MacOSX-SDK print-reexports;
    }
  else
    callPackage ../os-specific/darwin/apple-sdk {
      inherit (darwin) darwin-stubs print-reexports;
    };

  binutils-unwrapped = callPackage ../os-specific/darwin/binutils {
    inherit (darwin) cctools;
    inherit (pkgs) binutils-unwrapped;
    inherit (pkgs.llvmPackages_7) llvm;
  };

  binutils = pkgs.wrapBintoolsWith {
    libc = (x: builtins.trace ("darwin setting binutils.libc=${x}") x)(
      if stdenv.targetPlatform.isAarch64 then appleSDK.Libsystem else  pkgs.stdenv.cc.libc);
      # if stdenv.hostPlatform.isAarch64 then pkgs.stdenv.cc.libc
      # else if (stdenv.targetPlatform != stdenv.hostPlatform) && !useAppleSDK
      # then assert false; pkgs.libcCross
      # else pkgs.stdenv.cc.libc;
    bintools = darwin.binutils-unwrapped;
  };

  cctools = callPackage ../os-specific/darwin/cctools/port.nix {
    inherit (darwin) libobjc maloader libtapi;
    stdenv = if stdenv.isDarwin then stdenv else pkgs.libcxxStdenv;
    libcxxabi = pkgs.libcxxabi;
  };

  # TODO: remove alias.
  cf-private = darwin.apple_sdk.frameworks.CoreFoundation;

  DarwinTools = callPackage ../os-specific/darwin/DarwinTools { };

  darwin-stubs = callPackage ../os-specific/darwin/darwin-stubs { };

  print-reexports = callPackage ../os-specific/darwin/apple-sdk/print-reexports { };

  sigtool = callPackage ../os-specific/darwin/sigtool { };

  autoSignDarwinBinariesHook = makeSetupHook {
    substitutions = let
      iosPlatformArch = { parsed, ... }: {
        armv7a  = "armv7";
        aarch64 = "arm64";
        x86_64  = "x86_64";
      }.${parsed.cpu.name};
    in {
      inherit (targetPackages.stdenv.cc or stdenv.cc) targetPrefix;
      arch = iosPlatformArch stdenv.targetPlatform;
    };
    deps = [ darwin.sigtool ];
  } ../os-specific/darwin/sigtool/setup-hook.nix;

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

  libobjc = sdkPackages.objc4;

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

  # As the name says, this is broken, but I don't want to lose it since it's a direction we want to go in
  # libdispatch-broken = callPackage ../os-specific/darwin/swift-corelibs/libdispatch.nix { inherit (darwin) apple_sdk_sierra xnu; };

  darling = callPackage ../os-specific/darwin/darling/default.nix { };

  libtapi = callPackage ../os-specific/darwin/libtapi {};

  ios-deploy = callPackage ../os-specific/darwin/ios-deploy {};

  discrete-scroll = callPackage ../os-specific/darwin/discrete-scroll {
    inherit (darwin.apple_sdk.frameworks) Cocoa;
  };

})
