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

  adv_cmds-boot = callPackage ./adv_cmds/boot.nix {};

  packages = {
    inherit MacOSX-SDK;

    Libsystem = callPackage ./libSystem.nix {};
    LibsystemCross = pkgs.darwin.Libsystem;
    libiconv = callPackage ./libiconv.nix {};
    libcharset = callPackage ./libcharset.nix {};
    objc4 = callPackage ./libobjc.nix {};

    # alias
    configd = pkgs.darwin.apple_sdk.frameworks.SystemConfiguration;

    # built from source, non-libraries
    inherit (adv_cmds-boot) ps;
    bsdmake = callPackage ./bsdmake {};
  };
in packages
