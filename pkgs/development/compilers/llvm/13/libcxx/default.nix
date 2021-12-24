{ lib, stdenv, llvm_meta, src, cmake, python3, libcxxabi, fixDarwinDylibNames, version
, enableShared ? !stdenv.hostPlatform.isStatic
, headersOnly? false
}:

stdenv.mkDerivation rec {
  pname = "libcxx${lib.optionalString headersOnly "-headers"}";
  inherit version;

  inherit src;
  sourceRoot = "source/libcxx";

  outputs = [ "out" ] ++ lib.optionals (!headersOnly) [ "dev" ];

  patches = [
    ./gnu-install-dirs.patch
  ] ++ lib.optionals stdenv.hostPlatform.isMusl [
    ../../libcxx-0001-musl-hacks.patch
  ];

  preConfigure = lib.optionalString stdenv.hostPlatform.isMusl ''
    patchShebangs utils/cat_files.py
  '';

  nativeBuildInputs = [ cmake python3 ]
    ++ lib.optional stdenv.isDarwin fixDarwinDylibNames;

  buildInputs = lib.optionals (!headersOnly) [ libcxxabi ];

  cmakeFlags = [
    "-DLIBCXX_CXX_ABI=libcxxabi"
  ] ++ lib.optional (stdenv.hostPlatform.isMusl || stdenv.hostPlatform.isWasi) "-DLIBCXX_HAS_MUSL_LIBC=1"
    ++ lib.optional (stdenv.hostPlatform.useLLVM or false) "-DLIBCXX_USE_COMPILER_RT=ON"
    ++ lib.optional stdenv.hostPlatform.isWasm [
      "-DLIBCXX_ENABLE_THREADS=OFF"
      "-DLIBCXX_ENABLE_FILESYSTEM=OFF"
      "-DLIBCXX_ENABLE_EXCEPTIONS=OFF"
    ] ++ lib.optional (!enableShared) "-DLIBCXX_ENABLE_SHARED=OFF";

  buildFlags = if headersOnly then [ "generate-cxx-headers" ] else null;
  installTargets = if headersOnly then [ "install-cxx-headers" ] else null;

  # libcxx natively installs _some_ headers to $dev, but most to $out. If there
  # is anything at the destination, the automatic fixed output hooks will fail.
  # Move the stray headers back to $out for the hook.
  preFixup = lib.optionalString (!headersOnly) ''
    mv $dev/include/c++/v1/*.h $out/include/c++/v1
    rm -vr $dev/include
  '';

  passthru = {
    isLLVM = true;
  };

  meta = llvm_meta // {
    homepage = "https://libcxx.llvm.org/";
    description = "C++ standard library";
    longDescription = ''
      libc++ is an implementation of the C++ standard library, targeting C++11,
      C++14 and above.
    '';

    # "All of the code in libc++ is dual licensed under the MIT license and the
    # UIUC License (a BSD-like license)":
    license = with lib.licenses; [ mit ncsa ];
  };
}
