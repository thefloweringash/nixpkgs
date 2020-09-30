{ stdenv, stdenvNoCC, appleDerivation }:

let
  appleDerivation_ = appleDerivation.override {
    stdenv = stdenvNoCC;
  };
in

appleDerivation_ {
  dontBuild = true;

  postPatch = ''
    substituteInPlace Makefile \
        --replace '/bin/mkdir' 'mkdir' \
        --replace '/usr/bin/install' 'install'
  '';

  installFlags = [ "EXPORT_DSTDIR=/include/architecture" ];

  DSTROOT = "$(out)";

  meta = with stdenv.lib; {
    maintainers = with maintainers; [ copumpkin ];
    platforms   = platforms.darwin;
    license     = licenses.apsl20;
  };
}
