fixupOutputHooks+=('signDarwinBinariesIn $prefix')

checkRequiresSignature() {
  local file=$1
  local rc=0

  gensig --file "$file" check-requires-signature || rc=$?

  if [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; then
    return "$rc"
  fi

  echo "Unexpected exit status from gensig: $rc"
  exit 1
}

signIfRequired() {
  local file=$1
  if checkRequiresSignature "$file"; then
    CODESIGN_ALLOCATE=@targetPrefix@codesign_allocate codesign -f -s - "$file"
  fi
}

signDarwinBinariesIn() {
  local dir="$1"

  if [ ! -d "$dir" ]; then
    return 0
  fi

  if [ "${darwinDontCodeSign:-}" ]; then
    return 0
  fi

  while IFS= read -r -d $'\0' f; do
    signIfRequired "$f"
  done < <(find "$dir" -type f -print0)
}
