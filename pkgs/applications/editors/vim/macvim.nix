{ stdenv, fetchFromGitHub, ncurses, gettext
, pkgconfig, python, ruby, tcl, perl, luajit
, darwin, xcbuild, writeShellScriptBin
}:

let
  # Part of the xcbuild rule for copying something
  copypng = writeShellScriptBin "copypng" ''
    cp "$1" "$2"
  '';
in

stdenv.mkDerivation rec {
  name = "macvim-${version}";

  version = "8.1.950";  # Maybe we shouldn't use the vim version but the macvim snapshot number

  src = fetchFromGitHub {
    owner = "macvim-dev";
    repo = "macvim";
    rev = "snapshot-155";
    sha256 = "16v6amkjcgggmbkd9mlranw8hz67jpfjzys5ispp0g128y2sqkb7";
  };

  enableParallelBuilding = true;

  nativeBuildInputs = [ pkgconfig xcbuild ];
  buildInputs = [
    gettext ncurses luajit ruby tcl perl python
  ] ++ (with darwin.apple_sdk.frameworks; [ AppKit CoreServices Cocoa QuickLook ]);

  patches = [ ./macvim.patch ];

  notpostPatch = ''
    substituteInPlace src/MacVim/mvim --replace "# VIM_APP_DIR=/Applications" "VIM_APP_DIR=$out/Applications"
  '';

  configureFlags = [
      "--enable-cscope"
      "--enable-fail-if-missing"
      "--with-features=huge"
      "--enable-gui=macvim"
      "--enable-multibyte"
      "--enable-nls"
      "--enable-luainterp=dynamic"
      "--enable-pythoninterp=dynamic"
      "--enable-perlinterp=dynamic"
      "--enable-rubyinterp=dynamic"
      "--enable-tclinterp=yes"
      "--without-local-dir"
      "--with-luajit"
      "--with-lua-prefix=${luajit}"
      "--with-ruby-command=${ruby}/bin/ruby"
      "--with-tclsh=${tcl}/bin/tclsh"
      "--with-tlib=ncurses"
      "--with-compiledby=Nix"
  ];

  makeFlags = "PREFIX=$(out)";

  postInstall = ''
    mkdir -p $out/Applications
    cp -r src/MacVim/build/Release/MacVim.app $out/Applications
    rm -rf $out/MacVim.app

    rm $out/bin/{Vimdiff,Vimtutor,Vim,ex,rVim,rview,view}

    cp src/MacVim/mvim $out/bin
    cp src/vimtutor $out/bin

    for prog in "vimdiff" "vi" "vim" "ex" "rvim" "rview" "view"; do
      ln -s $out/bin/mvim $out/bin/$prog
    done

    # Fix rpaths
    exe="$out/Applications/MacVim.app/Contents/MacOS/Vim"
    libperl=$(dirname $(find ${perl} -name "libperl.dylib"))
    install_name_tool -add_rpath ${luajit}/lib $exe
    install_name_tool -add_rpath ${tcl}/lib $exe
    install_name_tool -add_rpath ${python}/lib $exe
    install_name_tool -add_rpath $libperl $exe
    install_name_tool -add_rpath ${ruby}/lib $exe
  '';

  meta = with stdenv.lib; {
    description = "Vim - the text editor - for macOS";
    homepage    = "https://github.com/macvim-dev/macvim";
    license = licenses.vim;
    maintainers = with maintainers; [ cstrahan ];
    platforms   = platforms.darwin;
  };
}
