{
  busybox = import <nix/fetchurl.nix> {
    url = http://nixos-arm.dezgeg.me/bootstrap-2017-04-13-1f32d4b4/armv7l/busybox;
    sha256 = "187xwzsng5lpak1nanrk88y4mlydmrbhx6la00rrd6kjx376s565";
    executable = true;
  };

  bootstrapTools = import <nix/fetchurl.nix> {
    url = https://s3.ap-northeast-1.amazonaws.com/nix-misc.cons.org.nz/stdenv-linux/armv7l-linux/c5aabb0d603e2c1ea05f5a93b3be82437f5ebf31/bootstrap-tools.tar.xz;
    sha256 = "11nhy1wkw53aby42mrfsam9f3npk4qzyzadnjwjkdlqavjmdqqj6";
  };
}
