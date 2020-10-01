{ stdenv, cmake, fetch, libcxx, llvm, version
, standalone ? false
  # on musl the shared objects don't build
, enableShared ? ! stdenv.hostPlatform.isMusl }:

assert (stdenv.hostPlatform != stdenv.buildPlatform) -> standalone;

stdenv.mkDerivation {
  pname = "libc++abi";
  inherit version;

  src = fetch "libcxxabi" "1zcqxsdjhawgz1cvpk07y3jl6fg9p3ay4nl69zsirqb2ghgyhhb2";

  nativeBuildInputs = [ cmake ];

  postUnpack = ''
    unpackFile ${libcxx.src}
    unpackFile ${llvm.src}
    cmakeFlagsArray=($cmakeFlagsArray -DLLVM_PATH=$PWD/$(ls -d llvm-*) -DLIBCXXABI_LIBCXX_PATH=$PWD/$(ls -d libcxx-*) )
  '' + stdenv.lib.optionalString stdenv.isDarwin ''
    export TRIPLE=${stdenv.hostPlatform.parsed.cpu.name}-apple-darwin
  '' + stdenv.lib.optionalString stdenv.hostPlatform.isMusl ''
    patch -p1 -d $(ls -d libcxx-*) -i ${../libcxx-0001-musl-hacks.patch}
  '';

  cmakeFlags =
     stdenv.lib.optional standalone "-DLLVM_ENABLE_LIBCXX=ON" ++
     stdenv.lib.optional (!enableShared) "-DLIBCXXABI_ENABLE_SHARED=OFF";

  installPhase = if stdenv.isDarwin
    then ''
      for file in lib/*.dylib; do
        # this should be done in CMake, but having trouble figuring out
        # the magic combination of necessary CMake variables
        # if you fancy a try, take a look at
        # https://gitlab.kitware.com/cmake/community/-/wikis/doc/cmake/RPATH-handling
        ${stdenv.cc.targetPrefix}install_name_tool -id $out/$file $file
      done
      make install
      install -d 755 $out/include
      install -m 644 ../include/*.h $out/include
    ''
    else ''
      install -d -m 755 $out/include $out/lib
      install -m 644 lib/libc++abi.a $out/lib
      ${stdenv.lib.optionalString enableShared "install -m 644 lib/libc++abi.so.1.0 $out/lib"}
      install -m 644 ../include/cxxabi.h $out/include
      ${stdenv.lib.optionalString enableShared "ln -s libc++abi.so.1.0 $out/lib/libc++abi.so"}
      ${stdenv.lib.optionalString enableShared "ln -s libc++abi.so.1.0 $out/lib/libc++abi.so.1"}
    '';

  meta = {
    homepage = "https://libcxxabi.llvm.org/";
    description = "A new implementation of low level support for a standard C++ library";
    license = with stdenv.lib.licenses; [ ncsa mit ];
    maintainers = with stdenv.lib.maintainers; [ vlstill ];
    platforms = stdenv.lib.platforms.unix;
  };
}
