{ stdenvNoCC, fetchurl, newScope, pkgs }:

let
  MacOSX-SDK = stdenvNoCC.mkDerivation rec {
    pname = "MacOSX-SDK";
    version = "11.0.0";

    src = fetchurl {
      url = "https://s3.ap-northeast-1.amazonaws.com/nix-misc.cons.org.nz/apple-silicon-wip/beta-sdk-linked.tar.gz";
      sha256 = "03l4rbcfl5vfvxhr9dakh8199grw814kivjhph3rbvrzd6hz34sa";
    };

    dontBuild = true;
    darwinDontCodeSign = true;

    installPhase = ''
      mkdir $out
      cp -r System usr $out/
    '';

    passthru = {
      inherit version;
    };
  };

  callPackage = newScope (packages // pkgs.darwin // { inherit MacOSX-SDK; });

  packages = {
    inherit (callPackage ./apple_sdk.nix {}) frameworks libs;

    # TODO: this is nice to be private. is it worth the callPackage above?
    # Probably, I don't think that callPackage costs much at all.
    # inherit MacOSX-SDK;

    Libsystem = callPackage ./libSystem.nix {};
    LibsystemCross = pkgs.darwin.Libsystem;
    libcharset = callPackage ./libcharset.nix {};
    libunwind = callPackage ./libunwind.nix {};
    objc4 = callPackage ./libobjc.nix {};
    ICU = callPackage ./ICU {};

    # questionable aliases
    configd = pkgs.darwin.apple_sdk.frameworks.SystemConfiguration;
    IOKit = pkgs.darwin.apple_sdk.frameworks.IOKit;
  };
in packages
