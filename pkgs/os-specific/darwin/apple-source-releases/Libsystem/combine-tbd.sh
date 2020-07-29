#!/usr/bin/env nix-shell
#!nix-shell -p yq -i bash

set -euo pipefail

# Generate TBD files for libsystem by inspecting the host system
# - Requires Xcode installed to generate (TODO: use libtapi instead)
# - Outputs to $PWD/tbd
# - Handles re-exported libraries with naive recursion

out=$PWD/tbd

mkdir -p $out

prefix=/usr/lib

result_name() {
  local lib=$1
  local result=$out${lib#$prefix}
  result=${result%.dylib}.tbd
  echo "$result"
}

export_library() {
  local lib=$1
  local result=$(result_name "$lib")

  echo "exporting $lib to $result"
  mkdir -p "$(dirname "$result")"

  # already exists
  # tapi stubify "$lib" -o "$result"

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

export_library /usr/lib/libSystem.B.dylib
