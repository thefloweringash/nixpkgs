#! @shell@
# shellcheck shell=bash

set -eu -o pipefail +o posix
shopt -s nullglob

if (( "${NIX_DEBUG:-0}" >= 7 )); then
    set -x
fi

# Work around for some odd behaviour where we can't codesign a file
# in-place if it has been called before. This happens for example if
# you try to fix-up a binary using strip/install_name_tool, after it
# had been used previous.  The solution is to copy the binary (with
# the corrupted signature from strip/install_name_tool) to some
# location, sign it there and move it back into place.
#
# This does not appear to happen with the codesign tool that ships
# with recent macOS BigSur installs on M1 arm64 machines.  However it
# had also been happening with the tools that shipped with the DTKs.
function sign {
    local tmpdir
    tmpdir=$(mktemp -d)

    # $1 is the file

    cp "$1" "$tmpdir"
    CODESIGN_ALLOCATE=@targetPrefix@codesign_allocate \
        @sigtool@/bin/codesign -f -s - "$tmpdir/$(basename "$1")"
    mv "$tmpdir/$(basename "$1")" "$1"
    rmdir "$tmpdir"
}

checkRequiresSignature() {
    local file=$1
    local rc=0

    @sigtool@/bin/gensig --file "$file" check-requires-signature || rc=$?

    if [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; then
        return "$rc"
    fi

    echo "Unexpected exit status from gensig: $rc"
    exit 1
}

signIfRequired() {
    local file=$1
    if checkRequiresSignature "$file"; then
        sign "$file"
    fi
}


extraAfter=()
extraBefore=()
params=("$@")

output=
inputs=()

restAreFiles=
prev=
for p in \
    ${extraBefore+"${extraBefore[@]}"} \
    ${params+"${params[@]}"} \
    ${extraAfter+"${extraAfter[@]}"}
do
    if [ "$restAreFiles" ]; then
        inputs+=("$p")
    else
        case "$prev" in
            -s|-R|-d|-arch)
                # Unrelated arguments with values
                ;;
            -o)
                # Explicit output
                output="$p"
                ;;
            *)
                # Any other orgument either takes no value, or is a file.
                if [[ "$p" != -* ]]; then
                    inputs+=("$p")
                fi
                ;;
        esac

        if [ "$p" == - ]; then
            restAreFiles=1
        fi
    fi

    prev="$p"
done

# Optionally print debug info.
if (( "${NIX_DEBUG:-0}" >= 1 )); then
    # Old bash workaround, see above.
    echo "extra flags before to @prog@:" >&2
    printf "  %q\n" ${extraBefore+"${extraBefore[@]}"}  >&2
    echo "original flags to @prog@:" >&2
    printf "  %q\n" ${params+"${params[@]}"} >&2
    echo "extra flags after to @prog@:" >&2
    printf "  %q\n" ${extraAfter+"${extraAfter[@]}"} >&2
fi

@prog@ \
    ${extraBefore+"${extraBefore[@]}"} \
    ${params+"${params[@]}"} \
    ${extraAfter+"${extraAfter[@]}"}

if [ "$output" ]; then
    # Single explicit output
    signIfRequired "$output"
else
    # Multiple inputs, rewritten in place
    for input in "${inputs[@]}"; do
      signIfRequired "$input"
    done
fi
