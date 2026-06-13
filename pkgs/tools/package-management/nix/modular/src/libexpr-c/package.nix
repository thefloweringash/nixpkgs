{
  lib,
  stdenv,
  mkMesonLibrary,

  nix-store-c,
  nix-expr,

  # Configuration Options

  version,
}:

mkMesonLibrary (finalAttrs: {
  pname = "nix-expr-c";
  inherit version;

  workDir = ./.;

  propagatedBuildInputs = [
    nix-store-c
    nix-expr
  ];

  mesonFlags = [
  ];

  env = lib.optionalAttrs (stdenv.hostPlatform.isPower && stdenv.hostPlatform.is32bit) {
    NIX_LDFLAGS = "-latomic";
  };

  meta = {
    platforms = lib.platforms.unix ++ lib.platforms.windows;
  };

})
