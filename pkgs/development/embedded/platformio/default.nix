
{ newScope, fetchFromGitHub, python3Packages }:

let
  callPackage = newScope self;

  version = "5.2.5";

  # pypi tarballs don't contain tests - https://github.com/platformio/platformio-core/issues/1964
  src = fetchFromGitHub {
    owner = "platformio";
    repo = "platformio-core";
    rev = "v${version}";
    sha256 = "1x1jqprwzpb09ca953rqbh2jvizh7bz8yj30krphb6007bnjilwy";
  };

  self = {
    platformio-core = python3Packages.callPackage ./core.nix { inherit version src; };

    platformio-chrootenv = callPackage ./chrootenv.nix { inherit version src; };
  };

in self
