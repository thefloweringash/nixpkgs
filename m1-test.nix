# "Comprehensive" set of tests that nothing is critically broken by the m1
# branch.
#
# The claim is that:
#   x86_64-darwin bootstrap tools can be recreated natively
#   aarch64-darwin bootstrap tools can be cross compiled by x86_64-darwin
#
# This test suite is probably best run on an aarch64-darwin computer with
# x86_64-darwin remote builders. If run with rosetta, there's a chance that
# platform mismatches will be unnoticed.

let
  systems = {
    intel = "x86_64-darwin";
    appleSilicon = "aarch64-darwin";
  };

  intel = {
    pkgs = import ./. {
      localSystem = systems.intel;
    };

    bootstrapTools = import ./pkgs/stdenv/darwin/make-bootstrap-tools.nix {
      system = systems.intel;
      crossSystem = systems.intel;
    };
  };

  appleSiliconCross = {
    pkgs = import ./. {
      localSystem = systems.intel;
      crossSystem = systems.appleSilicon;
    };

    bootstrapTools = import ./pkgs/stdenv/darwin/make-bootstrap-tools.nix {
      system = systems.intel;
      crossSystem = systems.appleSilicon;
    };
  };

  appleSiliconNative = {
    pkgs = import ./. {
      localSystem = systems.appleSilicon;
    };

    bootstrapTools = import ./pkgs/stdenv/darwin/make-bootstrap-tools.nix {
      system = systems.appleSilicon;
      crossSystem = systems.appleSilicon;
    };
  };

  generateTests = name: { pkgs, bootstrapTools }: {
    # is the stdenv buildable?
    "${name}_stdenv" = pkgs.stdenv;

    # can the stdenv build a package?
    "${name}_hello" = pkgs.hello;

    # can rebuilt bootstrap tools pass internal tests?
    "${name}_bootstrapTools_test" = bootstrapTools.test;

    # can bootstrap tools be rebuilt?
    "${name}_bootstrapTools" = bootstrapTools.dist;

    # can rebuilt bootstrap tools produce a stdenv natively?
    "${name}_bootstrapTools_stdenv" = bootstrapTools.test-pkgs.stdenv;

    # can rebuilt bootstrap tools build a package natively?
    "${name}_bootstrapTools_hello" = bootstrapTools.test-pkgs.hello;
  };

  lib = intel.pkgs.lib;

  allTests = lib.fold lib.mergeAttrs {} (
    lib.mapAttrsToList generateTests {
      inherit
        intel
        appleSiliconCross

        ## This is a desirable goal, but this currently relies on the
        ## provisional committed bootstrap tools, so let's ignore it for now.
        # appleSiliconNative

        ;
      }
    );

  knownFailingTests = [ ];
in
  builtins.removeAttrs allTests knownFailingTests

