let
  pkgs = import ./. {
    localSystem.system = "x86_64-darwin";
    crossSystem.system = "aarch64-darwin";
  };

  bootstrapTools = import ./pkgs/stdenv/darwin/make-bootstrap-tools.nix {
    system = "x86_64-darwin";
    crossSystem = "aarch64-darwin";
  };
in {
  inherit (pkgs) hello;

  bootstrapTools = bootstrapTools.dist;
}
