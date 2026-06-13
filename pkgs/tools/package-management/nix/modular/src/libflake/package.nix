{
  lib,
  stdenv,
  mkMesonLibrary,

  nix-util,
  nix-store,
  nix-fetchers,
  nix-expr,
  nlohmann_json,

  # Configuration Options

  version,
}:

mkMesonLibrary (finalAttrs: {
  pname = "nix-flake";
  inherit version;

  workDir = ./.;

  propagatedBuildInputs = [
    nix-store
    nix-util
    nix-fetchers
    nix-expr
    nlohmann_json
  ];

  env = lib.optionalAttrs (stdenv.hostPlatform.isPower && stdenv.hostPlatform.is32bit) {
    NIX_LDFLAGS = "-latomic";
  };

  meta = {
    platforms = lib.platforms.unix ++ lib.platforms.windows;
  };

})
