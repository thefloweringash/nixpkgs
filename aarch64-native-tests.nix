let
  appleSiliconSystem = {
    system = "aarch64-darwin";
  };

  pkgs = import ./. { localSystem = appleSiliconSystem; };

in {
  inherit (pkgs) hello nix git tmux ruby;
}
