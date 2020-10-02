let
  appleSiliconSystem = {
    system = "aarch64-darwin";
    # useLLVM = true;
  };

  pkgs = import ./. { crossSystem = appleSiliconSystem; };
in

{
  inherit pkgs;
  inherit (pkgs) buildPackages hello;
}
