fixupOutputHooks+=('signDarwinBinaries')

signDarwinBinary() {
  local path="$1"
  local sigsize arch

  arch=$(gensig --file "$path" show-arch)

  sigsize=$(gensig --file "$path" size)
  sigsize=$(( ((sigsize + 15) / 16) * 16 + 1024 ))

  @targetPrefix@codesign_allocate -i "$path" -a "$arch" "$sigsize" -o "$path.unsigned"
  gensig --identifier "$(basename "$path")" --file "$path.unsigned" inject
  mv -vf "$path.unsigned" "$path"
}

signDarwinBinaries() {
  local dir="$1"

  if [ "${darwinDontCodeSign:-}" ]; then
    return 0
  fi

  while IFS= read -r -d $'\0' f; do
    if gensig --file "$f" check-requires-signature; then
        signDarwinBinary "$f" ""
    fi
  done < <(find $prefix -type f -print0)
}
