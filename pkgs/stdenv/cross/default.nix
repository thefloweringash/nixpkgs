{ lib
, localSystem, crossSystem, config, overlays, crossOverlays ? []
}:

let
  bootStages = import ../. {
    inherit lib localSystem overlays;

    crossSystem = localSystem;
    crossOverlays = [];

    # Ignore custom stdenvs when cross compiling for compatability
    config = builtins.removeAttrs config [ "replaceStdenv" ];
  };

in lib.init bootStages ++ [

  # Regular native packages
  (somePrevStage: lib.last bootStages somePrevStage // {
    # It's OK to change the built-time dependencies
    allowCustomOverrides = true;
  })

  # Build tool Packages
  (vanillaPackages: {
    inherit config overlays;
    selfBuild = false;
    stdenv =
      assert vanillaPackages.stdenv.buildPlatform == localSystem;
      assert vanillaPackages.stdenv.hostPlatform == localSystem;
      assert vanillaPackages.stdenv.targetPlatform == localSystem;
      vanillaPackages.stdenv.override { targetPlatform = crossSystem; };
    # It's OK to change the built-time dependencies
    allowCustomOverrides = true;
  })

  # Run Packages
  (buildPackages: {
    inherit config;
    overlays = overlays ++ crossOverlays
      ++ (if (with crossSystem; isWasm || isRedox) then [(import ../../top-level/static.nix)] else []);
    selfBuild = false;
    stdenv = buildPackages.stdenv.override (old: rec {
      buildPlatform = localSystem;
      hostPlatform = crossSystem;
      targetPlatform = crossSystem;

      # Prior overrides are surely not valid as packages built with this run on
      # a different platform, and so are disabled.
      overrides = _: _: {};
      extraBuildInputs = [ ]; # Old ones run on wrong platform
      allowedRequisites = null;

      hasCC = !targetPlatform.isGhcjs;

      cc = if crossSystem.useiOSPrebuilt or false
             then buildPackages.darwin.iosSdkPkgs.clang
           else if crossSystem.useAndroidPrebuilt or false
             then buildPackages."androidndkPkgs_${crossSystem.ndkVer}".clang
           else if targetPlatform.isGhcjs
             # Need to use `throw` so tryEval for splicing works, ugh.  Using
             # `null` or skipping the attribute would cause an eval failure
             # `tryEval` wouldn't catch, wrecking accessing previous stages
             # when there is a C compiler and everything should be fine.
             then throw "no C compiler provided for this platform"
           else if crossSystem.isDarwin
             then buildPackages.llvmPackages_10.libcxxClang
           else if crossSystem.useLLVM or false
             then buildPackages.llvmPackages_8.lldClang
           else buildPackages.gcc;

      extraNativeBuildInputs = old.extraNativeBuildInputs
        ++ lib.optionals
             (hostPlatform.isLinux && !buildPlatform.isLinux)
             [ buildPackages.patchelf ]
        ++ lib.optional
             (let f = p: !p.isx86 || builtins.elem p.libc [ "musl" "wasilibc" "relibc" ] || p.isiOS || p.isGenode;
               in f hostPlatform && !(f buildPlatform) )
             buildPackages.updateAutotoolsGnuConfigScriptsHook
           # without proper `file` command, libtool sometimes fails
           # to recognize 64-bit DLLs
        ++ lib.optional (hostPlatform.config == "x86_64-w64-mingw32") buildPackages.file
        ;
    });
  })

]
