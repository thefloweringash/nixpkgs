{ lib, stdenv, fetchFromGitHub, cmake, python3, ncurses }:

stdenv.mkDerivation {
  pname = "libtapi";
  version = "1100.0.11";
  src = fetchFromGitHub {
    owner = "tpoechtrager";
    repo = "apple-libtapi";
    rev = "a66284251b46d591ee4a0cb4cf561b92a0c138d8";
    sha256 = "1rwxpbfvzh5mcaq8h9ga2b0wkc6r325s50spzrpismzl8b8ahj2s";
  };

  sourceRoot = "source/src/llvm";

  nativeBuildInputs = [ cmake python3 ];

  # ncurses is required here to avoid a reference to bootstrap-tools, which is
  # not allowed for the stdenv.
  buildInputs = [ ncurses ];

  cmakeFlags = [ "-DLLVM_INCLUDE_TESTS=OFF" ];

  # fixes: fatal error: 'clang/Basic/Diagnostic.h' file not found
  # adapted from upstream
  # https://github.com/tpoechtrager/apple-libtapi/blob/3cb307764cc5f1856c8a23bbdf3eb49dfc6bea48/build.sh#L58-L60
  preConfigure = ''
    INCLUDE_FIX="-I $PWD/projects/clang/include"
    INCLUDE_FIX+=" -I $PWD/build/projects/clang/include"

    cmakeFlagsArray+=(-DCMAKE_CXX_FLAGS="$INCLUDE_FIX")
  '';

  buildFlags = [ "clangBasic" "libtapi" ];

  installTargets = [ "install-libtapi" "install-tapi-headers" ];

  postInstall = stdenv.lib.optionalString stdenv.hostPlatform.isDarwin ''
    ${stdenv.cc.targetPrefix}install_name_tool -id $out/lib/libtapi.dylib $out/lib/libtapi.dylib
  '';

  meta = with lib; {
    license = licenses.apsl20;
    maintainers = with maintainers; [ matthewbauer ];
  };
}
