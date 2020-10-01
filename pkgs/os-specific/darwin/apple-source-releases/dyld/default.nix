{ stdenv, stdenvNoCC, appleDerivation }:

let
  appleDerivation_ = appleDerivation.override {
    stdenv = stdenvNoCC;
  };
in

appleDerivation_ {
  installPhase = ''
    mkdir -p $out/lib $out/include
    ln -s /usr/lib/dyld $out/lib/dyld
    cp -r include $out/
  '';

  meta = with stdenv.lib; {
    description = "Impure primitive symlinks to the Mac OS native dyld, along with headers";
    maintainers = with maintainers; [ copumpkin ];
    platforms   = platforms.darwin;
    license     = licenses.apsl20;
  };
}
