#!/usr/bin/env bash

set -euo pipefail

commit=$(git rev-parse HEAD)
result=$(nix-build --no-out-link pkgs/stdenv/darwin/make-bootstrap-tools.nix -A dist)

cat $result/nix-support/hydra-build-products | while read ftype fname fpath; do
  aws s3 cp $fpath s3://nix-misc.cons.org.nz/stdenv-darwin/x86_64/$(git rev-parse HEAD)/$(basename $fpath);
done

printf 'url = "https://s3.ap-northeast-1.amazonaws.com/nix-misc.cons.org.nz/stdenv-darwin/x86_64/%s/${file}";\n' $commit

cat $result/nix-support/hydra-build-products | while read ftype fname fpath; do
  hash=$(nix-hash --type sha256 --base32 --flat $fpath)
  printf '    %.7s = fetch { file = "%s"; sha256 = "%s"; };\n' $fname $(basename $fpath) $hash
done
