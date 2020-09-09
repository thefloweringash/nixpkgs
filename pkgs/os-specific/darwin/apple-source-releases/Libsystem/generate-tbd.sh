#!/usr/bin/env nix-shell
#!nix-shell -p yq -i bash

set -euo pipefail

# Generate TBD files for libsystem by inspecting the host system
# - Requires Xcode installed to generate (TODO: use libtapi instead)
# - Outputs to $PWD/tbd
# - Handles re-exported libraries with naive recursion

tapi() {
  /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/tapi "$@"
}

out=${GEN_TBD_OUT:-$PWD/tbd}

mkdir -p $out

install_name_prefix=/usr/lib
sysroot=${GEN_TBD_SYSROOT:-/}

result_name() {
  local lib=$1
  local result=$out${lib#$install_name_prefix}
  result=${result%.dylib}.tbd
  echo "$result"
}

export_library() {
  local lib=$1
  local result=$(result_name "$lib")
  local file=$sysroot/$lib

  echo "exporting $lib (from file $file) to $result"
  mkdir -p "$(dirname "$result")"

  tapi stubify  --filetype=tbd-v2 -isysroot "$sysroot" "$file" -o "$result"

  reexports=$(yq -r '.exports[]."re-exports" | if . == null then [] else . end | .[]' "$result")

  if [ -n "$reexports" ]; then
    while read exported_lib; do
      export_library "$exported_lib"
      cat "$(result_name "$exported_lib")" >> "$result"
    done <<<$reexports

    # Fixup manually combined yaml documents: remove end of document
    # markers, and recreate the final marker.
    sed -i"" -e '/^\.\.\.$/d' "$result"
    echo '...' >> "$result"
  fi
}

export_library "${1:-/usr/lib/libSystem.B.dylib}"
