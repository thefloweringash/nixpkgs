let
  pkgs = import ./. {};

  crossPkgs = import ./. {
    localSystem = "x86_64-darwin";
    crossSystem = "aarch64-darwin";
  };

  inherit (pkgs) lib;

  source = pkgs.writeText "main.c" ''
    int main() {}
  '';

  tests = {
    clangDefault = ''
      $CC -o test test.o
    '';

    clangEnv = ''
      export MACOSX_DEPLOYMENT_TARGET=10.14
      $CC -o test test.o
    '';

    clangExplicit = ''
      $CC -mmacos-version-min=10.14 -o test test.o
    '';

    ldDefault = ''
      $LD -L${pkgs.darwin.Libsystem}/lib -lSystem -o test test.o
    '';

    ldEnv = ''
      export MACOSX_DEPLOYMENT_TARGET=10.14
      $LD -L${pkgs.darwin.Libsystem}/lib -lSystem -o test test.o
    '';

    ldMacosVersion = ''
      $LD \
        -macos_version_min 10.14 \
        -L${pkgs.darwin.Libsystem}/lib -lSystem -o test test.o
    '';

    ldBothLegacyFlags = ''
      $LD \
        -macos_version_min 10.14 \
        -sdk_version 10.14 \
        -L${pkgs.darwin.Libsystem}/lib -lSystem -o test test.o
    '';

    ldSdkVersion = ''
      $LD \
        -sdk_version 10.14 \
        -L${pkgs.darwin.Libsystem}/lib -lSystem -o test test.o
    '';

    ldPlatformVersion = ''
      $LD \
        -platform_version macos 10.14 10.14 \
        -L${pkgs.darwin.Libsystem}/lib -lSystem -o test test.o
    '';
  };

  overrideTest = { stdenv, buildPackages }: stdenv.mkDerivation {
    name = "overrideTest";
    dontUnpack = true;

    depsBuildBuild = [ buildPackages.stdenv.cc ];

    MACOSX_DEPLOYMENT_TARGET_FOR_BUILD = "10.13";
    MACOSX_DEPLOYMENT_TARGET = "10.14";

    NIX_DEBUG = 3;

    buildPhase = ''
      set -x
      $CC_FOR_BUILD -c -o test-for-build.o ${source}
      $LD_FOR_BUILD -o    test-for-build   test-for-build.o

      $CC -c -o test.o ${source}
      $LD    -o test   test.o
      set +x
    '';

    installPhase = ''
      mkdir $out
      mv test test-for-build $out
    '';
  };


  stdenv = pkgs.stdenv;

  #stdenv = pkgs.overrideCC pkgs.stdenv (pkgs.stdenv.cc.override {
  #  bintools = pkgs.darwin.binutils.override {
  #    debuggingVersions = true;
  #  };
  #});

  buildTest = name: testScript: stdenv.mkDerivation {
    inherit name testScript;
    passAsFile = [ "testScript" "buildCommand" ];

    buildCommand = ''
      set -u
      echo $testScriptPath
      mkdir $out
      {
        NIX_DEBUG=3 $CC -o test.o -c ${source}
        NIX_DEBUG=3 $SHELL -x $testScriptPath
      } 2>&1 | tee $out/build.log
      ${pkgs.darwin.cctools}/bin/otool -l test> $out/load_commands
    '';
  };
in
  pkgs.runCommand "all-tests" {
    passthru = lib.mapAttrs buildTest tests // { overrideTest = crossPkgs.callPackage overrideTest {}; };
  } (
    ''
      mkdir $out
    '' +
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: script: ''
        ln -s ${buildTest name script} $out/${name}
      '') tests
    ) + ''
      cd $out
      {
        showCommand() {
          local cmdName=$1
          echo -ne "\t$cmdName: "
          awk "/$cmdName/ { show = 1 }; /Load command/ { show = 0 }; show" < $i | tr '\n' '\t'
          echo
        }

        for i in */load_commands; do
          echo $i
          showCommand LC_BUILD_VERSION
          showCommand LC_UUID
          showCommand LC_VERSION_MIN_MACOSX
        done

        echo

        echo "Linker warnings:"
        grep -nH 'warning' */build.log || true
      } > summary 2>&1
    ''
  )
