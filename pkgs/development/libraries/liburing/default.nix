{ stdenv, fetchgit
, fetchpatch
}:

stdenv.mkDerivation rec {
  pname = "liburing";
  version = "0.6pre600_${builtins.substring 0 8 src.rev}";

  src = fetchgit {
    url    = "http://git.kernel.dk/${pname}";
    rev    = "f2e1f3590f7bed3040bd1691676b50839f7d5c39";
    sha256 = "0wg0pgcbilbb2wg08hsvd18q1m8vdk46b3piz7qb1pvgyq01idj2";
  };

  separateDebugInfo = true;
  enableParallelBuilding = true;

  outputs = [ "out" "lib" "dev" "man" ];

  patches = stdenv.lib.optionals stdenv.hostPlatform.isAarch32 [
    # Backport unreleased "test: use mmap() directly in syzbot generated code"
    # https://git.kernel.dk/cgit/liburing/commit/?id=459e895f1167bbfc52649c204abc362a592d2bcb
    (fetchpatch {
      url = "https://git.kernel.dk/cgit/liburing/patch/?id=459e895f1167bbfc52649c204abc362a592d2bcb";
      sha256 = "1zkldq1fksag44iqcxj6z8qyd0s47a7dxgspq1skmjr79c76fng7";
    })
  ];

  configurePhase = ''
    ./configure \
      --prefix=$out \
      --includedir=$dev/include \
      --libdir=$lib/lib \
      --mandir=$man/share/man \
  '';

  # Copy the examples into $out.
  postInstall = ''
    mkdir -p $out/bin
    cp ./examples/io_uring-cp examples/io_uring-test $out/bin
    cp ./examples/link-cp $out/bin/io_uring-link-cp
    cp ./examples/ucontext-cp $out/bin/io_uring-ucontext-cp
  '';

  meta = with stdenv.lib; {
    description = "Userspace library for the Linux io_uring API";
    homepage    = "https://git.kernel.dk/cgit/liburing/";
    license     = licenses.lgpl21;
    platforms   = platforms.linux;
    maintainers = with maintainers; [ thoughtpolice ];
  };
}
