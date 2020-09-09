#!/usr/bin/env bash

set -x
set -euo pipefail
shopt -s nullglob

out=$PWD/frameworks-tbd
sysroot=/

while getopts "o:s:ra" opt; do
  case $opt in
    o) # output-dir
      out=$OPTARG
      ;;
    s) # sysroot
      sysroot=$OPTARG
      ;;
    \?)
      log "invalid option specified"
      exit 1
      ;;
  esac
done

stubify=$PWD/stubify.sh

# frameworkNamesJSON=$(nix-build --expr 'let pkgs = import ../../../.. {}; in pkgs.writeText "frameworks.json" (builtins.toJSON (builtins.attrNames pkgs.darwin.apple_sdk.frameworks))')
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
  local current="$(readlink "$sysroot/System/Library/Frameworks/$nested_path/Versions/Current")"
  if [ -z "$current" ]; then
    current=A
  fi

  # Keep track of if this is a child or a child rescue as with
  # ApplicationServices in the 10.9 SDK
  local isChild=0

  if [ -d "$sysroot/Library/Frameworks/$nested_path/Versions/$current/Headers" ]; then
    isChild=1
  elif [ -d "$sysroot/Library/Frameworks/$name.framework/Versions/$current/Headers" ]; then
    current="$(readlink "$sysroot/System/Library/Frameworks/$name.framework/Versions/Current")"
  fi

  $stubify -r -s "$sysroot" -o "$out" "/System/Library/Frameworks/$nested_path/Versions/$current/$name"

  pushd "$sysroot/System/Library/Frameworks/$nested_path/Versions/$current" >/dev/null
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
