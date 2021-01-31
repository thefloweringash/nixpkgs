# Unconditionally adding in platform version flags will result in warnings that
# will be treated as errors by some packages. Add any missing flags here.

# There are two things to be configured: the "platform version" (oldest
# supported version of macos, ios, etc), and the "sdk version".
#
# The modern way of configuring these is to use:
#    -platform_version $platform $platform_version $sdk_version"
#
# The old way is still supported, and uses flags like:
#    -${platform}_version_min $platform_version
#    -sdk_version $sdk_version
#
# If both styles are specified ld will combine them. If multiple versions are
# specified for the same platform, ld will emit an error.
#
# The following adds flags for whichever properties have not already been
# provided.


havePlatformVersionFlag=
haveDarwinSDKVersion=
haveDarwinPlatformVersion=

for p in ${params+"${params[@]}"}; do
    case "$p" in
        -macos_version_min|-ios_version_min)
            haveDarwinPlatformVersion=1
            ;;

        -sdk_version)
            haveDarwinSDKVersion=1
            ;;

        -platform_version)
            havePlatformVersionFlag=1
            ;;
    esac
done

# If the caller has set -platform_version, trust they're doing the right thing.
# This will be the typical case for clang in nixpkgs.
if [ ! "$havePlatformVersionFlag" ]; then
    if [ ! "$haveDarwinSDKVersion" ] && [ ! "$haveDarwinPlatformVersion" ]; then
        # Nothing provided. Use the modern "-platform_version" to set both.
        NIX_LDFLAGS_BEFORE_@suffixSalt@="-platform_version @darwinPlatform@ @darwinMinVersion@ @darwinSdkVersion@ $NIX_LDFLAGS_BEFORE_@suffixSalt@"
    elif [ ! "$haveDarwinSDKVersion" ]; then
        # Add missing sdk version
        NIX_LDFLAGS_BEFORE_@suffixSalt@="-sdk_version @darwinSdkVersion@ $NIX_LDFLAGS_BEFORE_@suffixSalt@"
    elif [ ! "$haveDarwinPlatformVersion" ]; then
        # Add missing platform version
        NIX_LDFLAGS_BEFORE_@suffixSalt@="-@darwinPlatform@_version_min @darwinSdkVersion@ $NIX_LDFLAGS_BEFORE_@suffixSalt@"
    fi
fi
