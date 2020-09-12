#!/usr/bin/env bash

set -euo pipefail

while getopts "o:s:" opt; do
  case $opt in
    s) # sysroot
      sysroot=$OPTARG
      ;;
    \?)
      log "invalid option specified"
      exit 1
      ;;
  esac
done

cleandir() {
  local dir=$1
  if [ -e "$dir" ]; then
    rm -r "$dir"
  fi
  echo "$dir"
}

./stubify.sh -r -s "$sysroot" \
  -o "$(cleandir ../apple-source-releases/Libsystem/tbd)" \
  /usr/lib/libSystem.B.dylib

./stubify.sh -s "$sysroot" \
  -o "$(cleandir ../apple-sdk/libcups-tbd)" \
  /usr/lib/libcups.2.dylib \
  /usr/lib/libcupscgi.1.dylib \
  /usr/lib/libcupsimage.2.dylib \
  /usr/lib/libcupsmime.1.dylib \
  /usr/lib/libcupsppdc.1.dylib

./stubify.sh -s "$sysroot" \
  -o "$(cleandir ../apple-sdk/libXplugin-tbd)" \
  /usr/lib/libXplugin.1.dylib

./frameworks-tbd.sh -s "$sysroot" \
  -o "$(cleandir ../apple-sdk/frameworks-tbd)"

./link-frameworks.rb '../apple-sdk/frameworks-tbd/**/*.tbd'
