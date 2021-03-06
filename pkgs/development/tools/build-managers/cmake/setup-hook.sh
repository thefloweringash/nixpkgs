addCMakeParams() {
    addToSearchPath CMAKE_PREFIX_PATH $1
}

fixCmakeFiles() {
    # Replace occurences of /usr and /opt by /var/empty.
    echo "fixing cmake files..."
    find "$1" \( -type f -name "*.cmake" -o -name "*.cmake.in" -o -name CMakeLists.txt \) -print |
        while read fn; do
            sed -e 's^/usr\([ /]\|$\)^/var/empty\1^g' -e 's^/opt\([ /]\|$\)^/var/empty\1^g' < "$fn" > "$fn.tmp"
            mv "$fn.tmp" "$fn"
        done
}

cmakeConfigurePhase() {
    runHook preConfigure

    if [ -z "$dontFixCmake" ]; then
        fixCmakeFiles .
    fi

    if [ -z "$dontUseCmakeBuildDir" ]; then
        mkdir -p build
        cd build
        cmakeDir=..
    fi

    if [ -z "$dontAddPrefix" ]; then
        cmakeFlags="-DCMAKE_INSTALL_PREFIX=$prefix $cmakeFlags"
    fi

    if [ -n "$crossConfig" ]; then
        # By now it supports linux builds only. We should set the proper
        # CMAKE_SYSTEM_NAME otherwise.
        # http://www.cmake.org/Wiki/CMake_Cross_Compiling
        #
        # Unfortunately cmake seems to expect absolute paths for ar, ranlib, and
        # strip. Otherwise they are taken to be relative to the source root of
        # the package being built.
        cmakeFlags="-DCMAKE_CXX_COMPILER=$crossConfig-c++ $cmakeFlags"
        cmakeFlags="-DCMAKE_C_COMPILER=$crossConfig-cc $cmakeFlags"
        cmakeFlags="-DCMAKE_AR=$(command -v $crossConfig-ar) $cmakeFlags"
        cmakeFlags="-DCMAKE_RANLIB=$(command -v $crossConfig-ranlib) $cmakeFlags"
        cmakeFlags="-DCMAKE_STRIP=$(command -v $crossConfig-strip) $cmakeFlags"
    fi

    # This installs shared libraries with a fully-specified install
    # name. By default, cmake installs shared libraries with just the
    # basename as the install name, which means that, on Darwin, they
    # can only be found by an executable at runtime if the shared
    # libraries are in a system path or in the same directory as the
    # executable. This flag makes the shared library accessible from its
    # nix/store directory.
    cmakeFlags="-DCMAKE_INSTALL_NAME_DIR=${!outputLib}/lib $cmakeFlags"
    cmakeFlags="-DCMAKE_INSTALL_LIBDIR=${!outputLib}/lib $cmakeFlags"
    cmakeFlags="-DCMAKE_INSTALL_INCLUDEDIR=${!outputDev}/include $cmakeFlags"

    # Avoid cmake resetting the rpath of binaries, on make install
    # And build always Release, to ensure optimisation flags
    cmakeFlags="-DCMAKE_BUILD_TYPE=${cmakeBuildType:-Release} -DCMAKE_SKIP_BUILD_RPATH=ON $cmakeFlags"

    if [ "$buildPhase" = ninjaBuildPhase ]; then
        cmakeFlags="-GNinja $cmakeFlags"
    fi

    echo "cmake flags: $cmakeFlags ${cmakeFlagsArray[@]}"

    cmake ${cmakeDir:-.} $cmakeFlags "${cmakeFlagsArray[@]}"

    if ! [[ -v enableParallelBuilding ]]; then
        enableParallelBuilding=1
        echo "cmake: enabled parallel building"
    fi

    runHook postConfigure
}

if [ -z "$dontUseCmakeConfigure" -a -z "$configurePhase" ]; then
    setOutputFlags=
    configurePhase=cmakeConfigurePhase
fi

addEnvHooks "$targetOffset" addCMakeParams

makeCmakeFindLibs(){
  isystem_seen=
  for flag in $NIX_CFLAGS_COMPILE $NIX_LDFLAGS; do
    if test -n "$isystem_seen" && test -d "$flag"; then
      isystem_seen=
      export CMAKE_INCLUDE_PATH="$CMAKE_INCLUDE_PATH${CMAKE_INCLUDE_PATH:+:}${flag}"
    else
      isystem_seen=
      case $flag in
        -I*)
          export CMAKE_INCLUDE_PATH="$CMAKE_INCLUDE_PATH${CMAKE_INCLUDE_PATH:+:}${flag:2}"
          ;;
        -L*)
          export CMAKE_LIBRARY_PATH="$CMAKE_LIBRARY_PATH${CMAKE_LIBRARY_PATH:+:}${flag:2}"
          ;;
        -F*)
          export CMAKE_FRAMEWORK_PATH="$CMAKE_FRAMEWORK_PATH${CMAKE_FRAMEWORK_PATH:+:}${flag:2}"
          ;;
        -isystem)
          isystem_seen=1
          ;;
      esac
    fi
  done
}

# not using setupHook, because it could be a setupHook adding additional
# include flags to NIX_CFLAGS_COMPILE
postHooks+=(makeCmakeFindLibs)
