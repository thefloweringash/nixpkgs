fixupOutputHooks+=('signDarwinBinariesIn $prefix')

signDarwinBinariesIn() {
  local dir="$1"

  if [ ! -d "$dir" ]; then
    return 0
  fi

  if [ "${darwinDontCodeSign:-}" ]; then
    return 0
  fi

  while IFS= read -r -d $'\0' f; do
    if gensig --file "$f" check-requires-signature; then
        CODESIGN_ALLOCATE=@targetPrefix@codesign_allocate codesign -s - "$f"
    fi
  done < <(find "$dir" -type f -print0)
}
