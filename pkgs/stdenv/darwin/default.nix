{ lib
, localSystem, crossSystem, config, overlays, crossOverlays ? []
# The version of darwin.apple_sdk used for sources provided by apple.
, appleSdkVersion ? "10.12"
# Minimum required macOS version, used both for compatibility as well as reproducability.
, macosVersionMin ? "10.12"
# Allow passing in bootstrap files directly so we can test the stdenv bootstrap process when changing the bootstrap tools
, bootstrapFiles ? let
  fetch = { file, sha256, executable ? true }: import <nix/fetchurl.nix> {
    url = "http://tarballs.nixos.org/stdenv-darwin/x86_64/d5bdfcbfe6346761a332918a267e82799ec954d2/${file}";
    inherit (localSystem) system;
    inherit sha256 executable;
  }; in {
    sh      = fetch { file = "sh";    sha256 = "07wm33f1yzfpcd3rh42f8g096k4cvv7g65p968j28agzmm2s7s8m"; };
    bzip2   = fetch { file = "bzip2"; sha256 = "0y9ri2aprkrp2dkzm6229l0mw4rxr2jy7vvh3d8mxv2698v2kdbm"; };
    mkdir   = fetch { file = "mkdir"; sha256 = "0sb07xpy66ws6f2jfnpjibyimzb71al8n8c6y4nr8h50al3g90nr"; };
    cpio    = fetch { file = "cpio";  sha256 = "0r5c54hg678w7zydx27bzl9p3v9fs25y5ix6vdfi1ilqim7xh65n"; };
    tarball = fetch { file = "bootstrap-tools.cpio.bz2"; sha256 = "18hp5w6klr8g307ap4368r255qpzg9r0vwg9vqvj8f2zy1xilcjf"; executable = false; };
  }
}:

assert crossSystem == localSystem;

let
  bootstrapClangVersion = "4.0.1";

  inherit (localSystem) system platform;

  commonImpureHostDeps = [
    "/bin/sh"
    "/usr/lib/libSystem.B.dylib"
    "/usr/lib/system/libunc.dylib" # This dependency is "hidden", so our scanning code doesn't pick it up
  ];
in rec {
  commonPreHook = ''
    export NIX_ENFORCE_NO_NATIVE=''${NIX_ENFORCE_NO_NATIVE-1}
    export NIX_ENFORCE_PURITY=''${NIX_ENFORCE_PURITY-1}
    export NIX_IGNORE_LD_THROUGH_GCC=1
    unset SDKROOT

    export MACOSX_DEPLOYMENT_TARGET=${macosVersionMin}

    # Workaround for https://openradar.appspot.com/22671534 on 10.11.
    export gl_cv_func_getcwd_abort_bug=no

    stripAllFlags=" " # the Darwin "strip" command doesn't know "-s"
  '';

  bootstrapTools = derivation {
    inherit system;

    name    = "bootstrap-tools";
    builder = bootstrapFiles.sh; # Not a filename! Attribute 'sh' on bootstrapFiles
    args    = [ ./unpack-bootstrap-tools.sh ];

    inherit (bootstrapFiles) mkdir bzip2 cpio tarball;
    reexportedLibrariesFile =
      ../../os-specific/darwin/apple-source-releases/Libsystem/reexported_libraries;

    __impureHostDeps = commonImpureHostDeps;
  };

  stageFun = step: last: {shell             ? "${bootstrapTools}/bin/bash",
                          overrides         ? (self: super: {}),
                          extraPreHook      ? "",
                          extraNativeBuildInputs,
                          extraBuildInputs,
                          libcxx,
                          allowedRequisites ? null}:
    let
      name = "bootstrap-stage${toString step}";

      buildPackages = lib.optionalAttrs (last ? stdenv) {
        inherit (last) stdenv;
      };

      cc = if last == null then "/dev/null" else
        last.pkgs.llvmPackages_7.libcxxClang;

      thisStdenv = import ../generic {
        name = "${name}-stdenv-darwin";

        inherit config shell extraNativeBuildInputs extraBuildInputs;
        allowedRequisites = if allowedRequisites == null then null else allowedRequisites ++ [
          (lib.debug.traceValFn (x: "${name} allowing cc.expand-response-params=${x}") cc.expand-response-params) cc.bintools
        ];

        buildPlatform = localSystem;
        hostPlatform = localSystem;
        targetPlatform = localSystem;

        inherit cc;

        preHook = lib.optionalString (shell == "${bootstrapTools}/bin/bash") ''
          # Don't patch #!/interpreter because it leads to retained
          # dependencies on the bootstrapTools in the final stdenv.
          dontPatchShebangs=1
        '' + ''
          ${commonPreHook}
          ${extraPreHook}
        '';
        initialPath  = [ bootstrapTools ];

        fetchurlBoot = import ../../build-support/fetchurl {
          inherit lib;
          stdenvNoCC = stage0.stdenv;
          curl = bootstrapTools;
        };

        # The stdenvs themselves don't use mkDerivation, so I need to specify this here
        __stdenvImpureHostDeps = commonImpureHostDeps;
        __extraImpureHostDeps = commonImpureHostDeps;

        extraAttrs = {
          inherit macosVersionMin appleSdkVersion platform;
        };
        overrides  = self: super: (overrides self super) // { fetchurl = thisStdenv.fetchurlBoot; };
      };

    in {
      inherit config overlays;
      stdenv = thisStdenv;
    };

  # Create the fundamental structure of a stage that inserts the bootstrap
  # tools into the package set.
  stage0 = stageFun 0 null {
    overrides = self: super: with stage0; {
      coreutils = { name = "bootstrap-stage0-coreutils"; outPath = bootstrapTools; };
      gnugrep   = { name = "bootstrap-stage0-gnugrep";   outPath = bootstrapTools; };

      darwin = super.darwin // {
        Libsystem = stdenv.mkDerivation {
          name = "bootstrap-stage0-Libsystem";
          buildCommand = ''
            mkdir -p $out
            ln -s ${bootstrapTools}/lib $out/lib
            ln -s ${bootstrapTools}/include-Libsystem $out/include
          '';
        };
        dyld = bootstrapTools;

        binutils = lib.makeOverridable (import ../../build-support/bintools-wrapper) {
          shell = "${bootstrapTools}/bin/bash";
          inherit (self) stdenvNoCC;

          nativeTools  = false;
          nativeLibc   = false;
          inherit (self) buildPackages coreutils gnugrep;
          libc         = self.pkgs.darwin.Libsystem;
          bintools     = { name = "bootstrap-stag0-binutils"; outPath = bootstrapTools; };
        };
      };

      llvmPackages_7 = super.llvmPackages_7 // (let
        tools = super.llvmPackages_7.tools.extend (_: _: {
          clang-unwrapped = {
            name = "bootstrap-stage0-clang-unwrapped";
            outPath = bootstrapTools;
            version = bootstrapClangVersion;
          };
        });

        libraries = super.llvmPackages_7.libraries.extend (_: _: {
          libcxx = stdenv.mkDerivation {
            name = "bootstrap-stage0-libcxx";
            phases = [ "installPhase" "fixupPhase" ];
            installPhase = ''
              mkdir -p $out/lib $out/include
              ln -s ${bootstrapTools}/lib/libc++.dylib $out/lib/libc++.dylib
              ln -s ${bootstrapTools}/include/c++      $out/include/c++
            '';
            passthru = {
              isLLVM = true;
            };
          };

          libcxxabi = stdenv.mkDerivation {
            name = "bootstrap-stage0-libcxxabi";
            buildCommand = ''
              mkdir -p $out/lib
              ln -s ${bootstrapTools}/lib/libc++abi.dylib $out/lib/libc++abi.dylib
            '';
          };

          compiler-rt = stdenv.mkDerivation {
            name = "bootstrap-stage0-compiler-rt";
            buildCommand = ''
              mkdir -p $out/lib
              ln -s ${bootstrapTools}/lib/libclang_rt* $out/lib
              ln -s ${bootstrapTools}/lib/darwin       $out/lib/darwin
            '';
          };
        });
      in { inherit tools libraries; } // tools // libraries);
    };

    extraNativeBuildInputs = [];
    extraBuildInputs = [];
    libcxx = null;
  };

  # Birth cctools-port and binutils
  stage1 = prevStage: let
    persistent = self: super: with prevStage; {
      inherit coreutils gnugrep;

      cmake = super.cmake.override {
        isBootstrap = true;
        useSharedLibraries = false;
      };

      python3 = super.python3Minimal;

      ninja = super.ninja.override { buildDocs = false; };

      llvmPackages_7 = super.llvmPackages_7 // (let
        tools = super.llvmPackages_7.tools.extend (_: _: {
          inherit (llvmPackages_7) clang-unwrapped;
        });
        libraries = super.llvmPackages_7.libraries.extend (_: _: {
          inherit (llvmPackages_7) compiler-rt libcxx libcxxabi;
        });
      in { inherit tools libraries; } // tools // libraries);

      darwin = super.darwin // {
        inherit (darwin)
          Libsystem;

        binutils-unwrapped = super.darwin.binutils-unwrapped.override {
          # llvm is only required for dsymutil. We're not ready to rebuild llvm
          # yet, so we retain the bootstrap tools version.
          llvm = { outPath = bootstrapTools; };
        };
      };
    };
  in with prevStage; stageFun 1 prevStage {
    extraPreHook = "export NIX_CFLAGS_COMPILE+=\" -F${bootstrapTools}/Library/Frameworks\"";
    extraNativeBuildInputs = [];
    extraBuildInputs = [ ];
    libcxx = pkgs.libcxx;

    allowedRequisites =
      [ bootstrapTools ] ++
      (with pkgs; [
        libcxx libcxxabi llvmPackages_7.compiler-rt
      ]) ++
      [ pkgs.darwin.Libsystem ];

    overrides = persistent;
  };

  # Birth libSystem and bash
  stage2 = prevStage: let
    persistent = self: super: with prevStage; {
      inherit
        zlib patchutils m4 scons flex perl bison unifdef unzip openssl python3
        libxml2 gettext sharutils gmp libarchive ncurses pkg-config libedit groff
        openssh sqlite sed serf openldap db cyrus-sasl expat apr-util subversion xz
        findfreetype libssh curl cmake autoconf automake libtool ed cpio coreutils
        libssh2 nghttp2 libkrb5 ninja gnugrep libffi binutils libiconv
        binutils-unwrapped;

      llvmPackages_7 = super.llvmPackages_7 // (let
        tools = super.llvmPackages_7.tools.extend (_: _: {
          inherit (llvmPackages_7) clang-unwrapped;
        });
        libraries = super.llvmPackages_7.libraries.extend (_: libSuper: {
          inherit (llvmPackages_7) compiler-rt libcxx libcxxabi;
        });
      in { inherit tools libraries; } // tools // libraries);

      darwin = super.darwin // {
        # TODO: why are we keeping these?
        inherit (darwin)
          binutils-unwrapped dyld xnu configd ICU libdispatch libclosure
          launchd CF cctools libtapi;

        binutils = darwin.binutils.override {
          libc = self.darwin.Libsystem;
        };
      };
    };
  in with prevStage; stageFun 2 prevStage {
    extraPreHook = ''
      export PATH_LOCALE=${pkgs.darwin.locale}/share/locale
    '';

    extraNativeBuildInputs = [ pkgs.xz ];
    extraBuildInputs = [ pkgs.darwin.CF ];
    libcxx = pkgs.libcxx;

    allowedRequisites =
      [ bootstrapTools ] ++
      (with pkgs; [
        xz.bin xz.out libcxx libcxxabi llvmPackages_7.compiler-rt
        zlib libxml2.out curl.out openssl.out libssh2.out
        nghttp2.lib libkrb5 coreutils gnugrep pcre.out gmp libiconv
        binutils binutils-unwrapped gettext ncurses
      ]) ++
      (with pkgs.darwin; [ binutils-unwrapped cctools dyld Libsystem CF ICU libtapi locale ]);

    overrides = persistent;
  };

  # Birth an entire clang toolchain from the bootstrap toolchain, including all
  # of clang-unwrapped, compiler-rt, libc++ and libc++abi.
  stage3 = prevStage: let
    persistent = self: super: with prevStage; {
      inherit
        patchutils m4 scons flex perl bison unifdef unzip openssl python3
        gettext sharutils libarchive pkg-config groff bash subversion
        openssh sqlite sed serf openldap db cyrus-sasl expat apr-util
        findfreetype libssh curl cmake autoconf automake libtool cpio
        libssh2 nghttp2 libkrb5 ninja coreutils gnugrep libiconv
        binutils-unwrapped;

      # Avoid pulling in a full python and its extra dependencies for the llvm/clang builds.
      libxml2 = super.libxml2.override { pythonSupport = false; };

      darwin = super.darwin // {
        inherit (darwin)
          binutils binutils-unwrapped dyld Libsystem xnu configd libdispatch libclosure launchd libiconv locale cctools libtapi;
      };
    };
  in with prevStage; stageFun 3 prevStage {
    shell = "${pkgs.bash}/bin/bash";

    # We have a valid shell here (this one has no bootstrap-tools runtime deps) so stageFun
    # enables patchShebangs above. Unfortunately, patchShebangs ignores our $SHELL setting
    # and instead goes by $PATH, which happens to contain bootstrapTools. So it goes and
    # patches our shebangs back to point at bootstrapTools. This makes sure bash comes first.
    extraNativeBuildInputs = with pkgs; [ xz ];
    extraBuildInputs = [ pkgs.darwin.CF pkgs.bash ];
    libcxx = pkgs.libcxx;

    extraPreHook = ''
      export PATH=${pkgs.bash}/bin:$PATH
      export PATH_LOCALE=${pkgs.darwin.locale}/share/locale
    '';

    # allowedRequisites = lib.debug.traceValFn (x: "stage 3 allowed\n" + lib.concatMapStringsSep "\n" (x: "  - ${x}")  x) (
    allowedRequisites =
      [ bootstrapTools ] ++
      (with pkgs; [
        libiconv gettext ncurses xz.bin xz.out bash binutils-unwrapped
        libcxx libcxxabi llvmPackages_7.compiler-rt llvmPackages_7.clang-unwrapped
        zlib libxml2.out curl.out openssl.out libssh2.out
        nghttp2.lib libkrb5 coreutils gnugrep
      ]) ++
      (with pkgs.darwin; [
        binutils binutils-unwrapped binutils.expand-response-params
        cctools dyld ICU Libsystem locale libtapi
      ]);

    overrides = persistent;
  };

  # Rebuild most of the things we built in stage 1
  stage4 = prevStage: let
    persistent = self: super: with prevStage; {
      inherit
        bash python3 ncurses libffi zlib pcre cmake patchutils ninja libxml2;

      # Hack to make sure we don't link ncurses in bootstrap tools. The proper
      # solution is to avoid passing -L/nix-store/...-bootstrap-tools/lib,
      # quite a sledgehammer just to get the C runtime.
      gettext = super.gettext.overrideAttrs (drv: {
        configureFlags = drv.configureFlags ++ [
          "--disable-curses"
        ];
      });

      llvmPackages_7 = super.llvmPackages_7 // (let
        tools = super.llvmPackages_7.tools.extend (llvmSelf: _: {
          clang-unwrapped = llvmPackages_7.clang-unwrapped.override { llvm = llvmSelf.llvm; };
          llvm = llvmPackages_7.llvm.override { inherit libxml2; };
        });
        libraries = super.llvmPackages_7.libraries.extend (llvmSelf: _: {
          inherit (llvmPackages_7) libcxx libcxxabi compiler-rt;
        });
      in { inherit tools libraries; } // tools // libraries);

      darwin = super.darwin // rec {
        inherit (darwin) dyld Libsystem libiconv locale;

        CF = super.darwin.CF.override {
          inherit libxml2;
          python3 = prevStage.python3;
        };
      };
    };
  in with (lib.debug.traceValFn (x: "stage3.stdenv=${x.stdenv}") prevStage); stageFun 4 prevStage {
    shell = "${pkgs.bash}/bin/bash";
    extraNativeBuildInputs = with pkgs; [ xz ];
    extraBuildInputs = [ pkgs.darwin.CF pkgs.bash ];
    libcxx = pkgs.libcxx;

    extraPreHook = ''
      export PATH_LOCALE=${pkgs.darwin.locale}/share/locale
    '';
    overrides = persistent;
  };

  # Final stdenv that rebuilds ???
  stdenvDarwin = prevStage: let
    pkgs = prevStage;
    persistent = self: super: with prevStage; {
      inherit
        gnumake gzip gnused bzip2 gawk ed xz patch bash
        ncurses libffi zlib llvm gmp pcre gnugrep
        coreutils findutils diffutils patchutils;

      llvmPackages_7 = super.llvmPackages_7 // (let
        tools = super.llvmPackages_7.tools.extend (_: super: {
          inherit (llvmPackages_7) llvm clang-unwrapped;
        });
        libraries = super.llvmPackages_7.libraries.extend (_: _: {
          inherit (llvmPackages_7) compiler-rt libcxx libcxxabi;
        });
      in { inherit tools libraries; } // tools // libraries);

      darwin = super.darwin // {
        inherit (darwin) dyld ICU Libsystem libiconv;
      } // lib.optionalAttrs (super.stdenv.targetPlatform == localSystem) {
        inherit (darwin) binutils binutils-unwrapped cctools;
      };
    } // lib.optionalAttrs (super.stdenv.targetPlatform == localSystem) {
      # Need to get rid of these when cross-compiling.
      inherit binutils binutils-unwrapped;
    };
  in import ../generic rec {
    name = "stdenv-darwin";

    inherit config;
    inherit (pkgs.stdenv) fetchurlBoot;

    buildPlatform = localSystem;
    hostPlatform = localSystem;
    targetPlatform = localSystem;

    preHook = commonPreHook + ''
      export NIX_COREFOUNDATION_RPATH=${pkgs.darwin.CF}/Library/Frameworks
      export PATH_LOCALE=${pkgs.darwin.locale}/share/locale
    '';

    __stdenvImpureHostDeps = commonImpureHostDeps;
    __extraImpureHostDeps = commonImpureHostDeps;

    initialPath = import ../common-path.nix { inherit pkgs; };
    shell       = "${pkgs.bash}/bin/bash";

    cc = pkgs.llvmPackages.libcxxClang.override {
      cc = pkgs.llvmPackages.clang-unwrapped;
    };

    extraNativeBuildInputs = [];
    extraBuildInputs = [ pkgs.darwin.CF ];

    extraAttrs = {
      libc = pkgs.darwin.Libsystem;
      shellPackage = pkgs.bash;
      inherit macosVersionMin appleSdkVersion platform bootstrapTools;
    };

    allowedRequisites = (with pkgs; [
      xz.out xz.bin libcxx libcxxabi gmp.out gnumake findutils bzip2.out
      bzip2.bin llvmPackages.llvm llvmPackages.llvm.lib llvmPackages.compiler-rt llvmPackages.compiler-rt.dev
      zlib.out zlib.dev libffi.out coreutils ed diffutils gnutar
      gzip ncurses.out ncurses.dev ncurses.man gnused bash gawk
      gnugrep llvmPackages.clang-unwrapped llvmPackages.clang-unwrapped.lib patch pcre.out gettext
      binutils.bintools darwin.binutils darwin.binutils.bintools
      curl.out openssl.out libssh2.out nghttp2.lib libkrb5
      cc.expand-response-params libxml2.out
    ]) ++ (with pkgs.darwin; [
      dyld Libsystem CF cctools ICU libiconv locale libtapi
    ]);

    overrides = lib.composeExtensions persistent (self: super: {
      clang = cc;
      llvmPackages = super.llvmPackages // { clang = cc; };
      inherit cc;

      darwin = super.darwin // {
        inherit (prevStage.darwin) CF;
        xnu = super.darwin.xnu.override { inherit (prevStage) python3; };
      };
    });
  };

  stagesDarwin = [
    ({}: stage0)
    stage1
    stage2
    stage3
    stage4
    (prevStage: {
      inherit config overlays;
      stdenv = stdenvDarwin prevStage;
    })
  ];
}
