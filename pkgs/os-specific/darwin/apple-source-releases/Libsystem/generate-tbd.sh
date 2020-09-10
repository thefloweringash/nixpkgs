#!/usr/bin/env nix-shell
#!nix-shell -p yq -i bash

set -euo pipefail

# Generate TBD files for libsystem by inspecting the host system
# - Requires Xcode installed to generate (TODO: use libtapi instead)
# - Outputs to $PWD/tbd
# - Handles re-exported libraries with naive recursion

log() {
  echo "$@" >&2
}

tapi() {
  /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/tapi "$@"
}

out=${GEN_TBD_OUT:-$PWD/tbd}

mkdir -p $out

sysroot=${GEN_TBD_SYSROOT:-/}

result_name() {
  local lib=$1
  local result=$out$lib
  result=${result%.dylib}.tbd
  echo "$result"
}

export_library() {
  local lib=$1
  local result=$(result_name "$lib")
  local file=$sysroot/$lib

  log -e "tapi stubify\n\tlib: $lib\n\tfile: $file\n\tto: $result"
  mkdir -p "$(dirname "$result")"

  tapi stubify  --filetype=tbd-v2 -isysroot "$sysroot" "$file" -o "$result"

  reexports=($(yq -r '.exports[]."re-exports" | if . == null then [] else . end | .[]' "$result"))

  if [ "${#reexports[@]}" -gt 0 ]; then
    log "Discovered ${#reexports[@]} re-exported libraries"

    for exported_lib in "${reexports[@]}"; do
      log -e "\t -${exported_lib}"
    done

    for exported_lib in "${reexports[@]}"; do
      log "Processing re-exported library: $exported_lib"
      export_library "$exported_lib"

      reexported_result=$(result_name "$exported_lib")
      log -e "Appending re-exported library\n\tfrom: $reexported_result\n\tto: $result"
      cat "$reexported_result" >> "$result"
    done

    # Fixup manually combined yaml documents: remove end of document
    # markers, and recreate the final marker.
    sed -i"" -e '/^\.\.\.$/d' "$result"
    echo '...' >> "$result"
  fi
}

export_library "${1:-/usr/lib/libSystem.B.dylib}"
