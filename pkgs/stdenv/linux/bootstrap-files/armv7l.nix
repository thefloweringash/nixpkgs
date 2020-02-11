{
  # built from https://github.com/NixOS/nixpkgs/pull/79793
  # cherry-picked onto master for cross fixes (infinite recursion)
  # uploaded to s3
  # only for testing locally

  busybox = import <nix/fetchurl.nix> {
    url = https://s3.ap-northeast-1.amazonaws.com/nix-misc.cons.org.nz/h3l1fq2zi9xw56wjmdkr8j0m9g8f3w58-stdenv-bootstrap-tools-armv7l-unknown-linux-gnueabihf/on-server/busybox;
    sha256 = "18qc6w2yykh7nvhjklsqb2zb3fjh4p9r22nvmgj32jr1mjflcsjn";
    executable = true;
  };

  bootstrapTools = import <nix/fetchurl.nix> {
    url = https://s3.ap-northeast-1.amazonaws.com/nix-misc.cons.org.nz/h3l1fq2zi9xw56wjmdkr8j0m9g8f3w58-stdenv-bootstrap-tools-armv7l-unknown-linux-gnueabihf/on-server/bootstrap-tools.tar.xz;
    sha256 = "1vgmx4075379cpj9ivskl1aarbdcm59qzvgh7vgjqxh9rww2j2iw";
  };
}
