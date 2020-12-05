{ stdenv, runCommand, makeWrapper, appleDerivation, xcbuildHook, llvmPackages }:

let
  # rpcgen calls `cpp` internally. Provide the correct value for -arch.
  platformArch = { parsed, ... }: {
    armv7a  = "armv7";
    aarch64 = "arm64";
    x86_64  = "x86_64";
  }.${parsed.cpu.name};

  cppWrapper = runCommand "cpp-wrapper" {
    nativeBuildInputs = [ makeWrapper ];
  } ''
    mkdir -p $out/bin
    makeWrapper ${llvmPackages.clang-unwrapped}/bin/clang-cpp $out/bin/cpp \
      --add-flags "-arch ${platformArch stdenv.targetPlatform}"
  '';
in
appleDerivation {
  nativeBuildInputs = [ xcbuildHook ];

  patches = [
    # The following copied from
    # https://github.com/Homebrew/homebrew-core/commit/712ed3e948868e17f96b7e59972b5f45d4faf688
    # is needed to build libvirt.
    ./rpcgen-support-hyper-and-quad-types.patch
  ];

  postPatch = ''
    substituteInPlace rpcgen/rpc_main.c \
      --replace "/usr/bin/cpp" "${cppWrapper}/bin/cpp"
  '';

  # temporary install phase until xcodebuild has "install" support
  installPhase = ''
    for f in Products/Release/*; do
      if [ -f $f ]; then
        install -D $f $out/bin/$(basename $f)
      fi
    done

    for n in 1; do
      mkdir -p $out/share/man/man$n
      install */*.$n $out/share/man/man$n
    done
  '';

  meta = {
    platforms = stdenv.lib.platforms.darwin;
    maintainers = with stdenv.lib.maintainers; [ matthewbauer ];
  };
}
