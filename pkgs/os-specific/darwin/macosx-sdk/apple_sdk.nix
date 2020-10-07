{ stdenvNoCC, buildPackages, fetchurl, xar, cpio, pkgs, python3, pbzx, lib, MacOSX-SDK }:

let
  stdenv = stdenvNoCC;

  mkFrameworkSubs = name: deps:
  let
    deps' = deps // { "${name}" = placeholder "out"; };
    substArgs = lib.concatMap (x: [ "--subst-var-by" x deps'."${x}" ]) (lib.attrNames deps');
  in lib.escapeShellArgs substArgs;

  framework = name: deps: stdenv.mkDerivation {
    pname = "apple-framework-${name}";
    version = MacOSX-SDK.version;

    dontUnpack = true;

    # because we copy files from the system
    preferLocalBuild = true;

    disallowedRequisites = [ MacOSX-SDK ];

    nativeBuildInputs = [ buildPackages.darwin.print-reexports ];

    extraTBDFiles = [];

    installPhase = ''
      mkdir -p $out/Library/Frameworks

      cp -vr ${MacOSX-SDK}/System/Library/Frameworks/${name}.framework $out/Library/Frameworks

      # Fix and check tbd re-export references
      find $out -name '*.tbd' -type f | while read tbd; do
        echo "Fixing re-exports in $tbd"
        substituteInPlace "$tbd" ${mkFrameworkSubs name deps}

        echo "Checking re-exports in $tbd"
        print-reexports "$tbd" | while read target; do
          local expected="''${target%.dylib}.tbd"
          if ! [ -e "$expected" ]; then
            echo -e "Re-export missing:\n\t$target\n\t(expected $expected)"
            echo -e "While processing\n\t$tbd"
            exit 1
          else
            echo "Re-exported target $target ok"
          fi
        done
      done
    '';

    propagatedBuildInputs = builtins.attrValues deps;

    meta = with stdenv.lib; {
      description = "Apple SDK framework ${name}";
      maintainers = with maintainers; [ copumpkin ];
      platforms   = platforms.darwin;
    };
  };

  tbdOnlyFramework = name: { private ? true }: stdenv.mkDerivation {
    name = "apple-framework-${name}";
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/Library/Frameworks/
      cp -r ${MacOSX-SDK}/System/Library/${lib.optionalString private "Private"}Frameworks/${name}.framework \
        $out/Library/Frameworks
      # NOTE there's no re-export checking here, this is probably wrong
    '';
  };
in rec {
  libs = {
    xpc = stdenv.mkDerivation {
      name   = "apple-lib-xpc";
      dontUnpack = true;

      installPhase = ''
        mkdir -p $out/include
        pushd $out/include >/dev/null
        cp -r "${MacOSX-SDK}/usr/include/xpc" $out/include/xpc
        cp "${MacOSX-SDK}/usr/include/launch.h" $out/include/launch.h
        popd >/dev/null
      '';
    };

    Xplugin = stdenv.mkDerivation {
      name   = "apple-lib-Xplugin";
      dontUnpack = true;

      propagatedBuildInputs = with frameworks; [
        OpenGL ApplicationServices Carbon IOKit CoreGraphics CoreServices CoreText
      ];

      installPhase = ''
        mkdir -p $out/include $out/lib
        ln -s "${MacOSX-SDK}/include/Xplugin.h" $out/include/Xplugin.h
        cp ${MacOSX-SDK}/usr/lib/libXplugin.1.tbd $out/lib
        ln -s libXplugin.1.tbd $out/lib/libXplugin.tbd
      '';
    };

    utmp = stdenv.mkDerivation {
      name   = "apple-lib-utmp";
      dontUnpack = true;

      installPhase = ''
        mkdir -p $out/include
        pushd $out/include >/dev/null
        ln -s "${MacOSX-SDK}/include/utmp.h"
        ln -s "${MacOSX-SDK}/include/utmpx.h"
        popd >/dev/null
      '';
    };
  };

  overrides = super: lib.genAttrs [ "ContactsPersistence" "UIFoundation" "GameCenter" ] (x: tbdOnlyFramework x {});

  bareFrameworks = stdenv.lib.mapAttrs framework (import ./frameworks.nix {
    inherit frameworks libs;
    inherit (pkgs.darwin) libobjc;
  });

  frameworks = bareFrameworks // overrides bareFrameworks;
}
