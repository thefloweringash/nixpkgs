{
  lib,
  stdenv,
  mkMesonLibrary,

  nix-util,
  nix-store,
  nlohmann_json,
  libgit2,

  # Configuration Options

  version,
}:

mkMesonLibrary (finalAttrs: {
  pname = "nix-fetchers";
  inherit version;

  workDir = ./.;

  buildInputs = [
    libgit2
  ];

  propagatedBuildInputs = [
    nix-store
    nix-util
    nlohmann_json
  ];

  env = lib.optionalAttrs (stdenv.hostPlatform.isPower && stdenv.hostPlatform.is32bit) {
    NIX_LDFLAGS = "-latomic";
  };

  meta = {
    platforms = lib.platforms.unix ++ lib.platforms.windows;
  };

})
