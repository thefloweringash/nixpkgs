let
  pkgs = import ./. { localSystem.system = "aarch64-darwin"; };

in {
  inherit (pkgs) hello nix git tmux ruby;
}
