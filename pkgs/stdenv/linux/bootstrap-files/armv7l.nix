{
  # https://hydra.nixos.org/build/111556965
  busybox = import <nix/fetchurl.nix> {
    url = https://s3.ap-northeast-1.amazonaws.com/nix-misc.cons.org.nz/bryxbn910b5cf1q54yxsw4dzyckdh3dy-busybox;
    sha256 = "18qc6w2yykh7nvhjklsqb2zb3fjh4p9r22nvmgj32jr1mjflcsjn";
    executable = true;
  };

  # https://hydra.nixos.org/build/111556911
  bootstrapTools = import <nix/fetchurl.nix> {
    url = https://s3.ap-northeast-1.amazonaws.com/nix-misc.cons.org.nz/dnd817yvqvbz3p77km228px9r9a7wc9n-bootstrap-tools.tar.xz;
    sha256 = "0l0544ixi9x2y23c9fmwyvb1y9kd9gb3yamnr73mdf5f49vjvykr";
  };
}
