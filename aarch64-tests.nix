let
  appleSiliconSystem = {
    system = "aarch64-darwin";
    # useLLVM = true;
  };

  pkgs = import ./. { crossSystem = appleSiliconSystem; };

  bootstrapTools = import ./pkgs/stdenv/darwin/make-bootstrap-tools.nix {
    crossSystem = "aarch64-darwin";
  };
in {
  inherit (pkgs) hello;

  bootstrapTools = bootstrapTools.dist;
}
