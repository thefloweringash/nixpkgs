set -euo pipefail

# Unpack the bootstrap tools tarball.
echo Unpacking the bootstrap tools...
$mkdir $out
$bzip2 -d < $tarball | (cd $out && $cpio -i)

export PATH=$out/bin

# This looks a lot like a third copy of signDarwinBinary and it is, but it
# interleaves the install_name_tool such that the target library on disk is
# always signed, so we can keep running as we change the libraries used by the
# bootstrap tools themselves.
updateInstallName() {
  local path="$1"
  local sigsize arch

  arch=$(gensig --file "$path" show-arch)

  sigsize=$(gensig --file "$path" size)
  sigsize=$(( ((sigsize + 15) / 16) * 16 + 1024 ))

  codesign_allocate -i "$path" -a "$arch" "$sigsize" -o "$path.unsigned"

  install_name_tool -id "$path" "$path.unsigned"

  # if this library loads any other library by rpath, then we need to add the
  # library dir to our library rpath.
  if otool -L "$path" | grep -q '@rpath'; then
    install_name_tool -add_rpath $out/lib "$lib"
  fi

  gensig --identifier "$(basename "$path")" --file "$path.unsigned" inject
  mv -f "$path.unsigned" "$path"
}

find $out

ln -s bash $out/bin/sh
ln -s bzip2 $out/bin/bunzip2

find $out/lib -type f -name '*.dylib' -print0 | while IFS= read -r -d $'\0' lib; do
  updateInstallName "$lib"
done

# Provide a gunzip script.
cat > $out/bin/gunzip <<EOF
#!$out/bin/sh
exec $out/bin/gzip -d "\$@"
EOF
chmod +x $out/bin/gunzip

# Provide fgrep/egrep.
echo "#! $out/bin/sh" > $out/bin/egrep
echo "exec $out/bin/grep -E \"\$@\"" >> $out/bin/egrep
echo "#! $out/bin/sh" > $out/bin/fgrep
echo "exec $out/bin/grep -F \"\$@\"" >> $out/bin/fgrep

cat >$out/bin/dsymutil << EOF
#!$out/bin/sh
EOF

chmod +x $out/bin/egrep $out/bin/fgrep $out/bin/dsymutil
