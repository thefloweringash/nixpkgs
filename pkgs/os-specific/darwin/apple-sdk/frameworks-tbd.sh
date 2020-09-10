#!/usr/bin/env bash

set -x
set -euo pipefail
shopt -s nullglob

GEN_TBD=$PWD/generate-tbd.sh

SYSROOT=$PWD
out=$PWD/frameworks-tbd

export GEN_TBD_SYSROOT=$SYSROOT
export GEN_TBD_OUT=$out

frameworkNamesJSON=$(nix-build --expr 'let pkgs = import <nixpkgs> {}; in pkgs.writeText "frameworks.json" (builtins.toJSON (builtins.attrNames pkgs.darwin.apple_sdk.frameworks))')

# Derived from the linkFramework in nixpkgs
stubifyFramework() {
  local path="$1"
  local nested_path="$1"
  if [ "$path" == "JavaNativeFoundation.framework" ]; then
    local nested_path="JavaVM.framework/Versions/A/Frameworks/JavaNativeFoundation.framework"
  fi
  if [ "$path" == "JavaRuntimeSupport.framework" ]; then
    local nested_path="JavaVM.framework/Versions/A/Frameworks/JavaRuntimeSupport.framework"
  fi
  local name="$(basename "$path" .framework)"
  local current="$(readlink "$SYSROOT/System/Library/Frameworks/$nested_path/Versions/Current")"
  if [ -z "$current" ]; then
    current=A
  fi

  # Keep track of if this is a child or a child rescue as with
  # ApplicationServices in the 10.9 SDK
  local isChild=0

  if [ -d "$SYSROOT/Library/Frameworks/$nested_path/Versions/$current/Headers" ]; then
    isChild=1
  elif [ -d "$SYSROOT/Library/Frameworks/$name.framework/Versions/$current/Headers" ]; then
    current="$(readlink "$SYSROOT/System/Library/Frameworks/$name.framework/Versions/Current")"
  fi

  $GEN_TBD "/System/Library/Frameworks/$nested_path/Versions/$current/$name"

  pushd "$SYSROOT/System/Library/Frameworks/$nested_path/Versions/$current" >/dev/null
  local children=$(echo Frameworks/*.framework)
  popd >/dev/null

  for child in $children; do
    childpath="$path/Versions/$current/$child"
    stubifyFramework "$childpath"
  done
}

jq -r '.[]' < "$frameworkNamesJSON" | while read name; do
  echo "Stubifying framework $name"
  if [ "$name" = Kernel ]; then
    echo "Skipping $name"
  else
    stubifyFramework "${name}.framework"
  fi
done
