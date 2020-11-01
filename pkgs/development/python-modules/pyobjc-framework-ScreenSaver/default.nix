{ stdenv, buildPythonPackage, pythonOlder, fetchPypi, darwin, python,
pyobjc-core, pyobjc-framework-Cocoa }:

buildPythonPackage rec {
  pname = "pyobjc-framework-ScreenSaver";
  version = "6.2.2";

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0fs54s1sbf8vvicnxhfvhbfpvj53x6g4n6d94f3vrgg1dhf9yizh";
  };
  
  postPatch = ''
    # Hard code correct SDK version
    substituteInPlace pyobjc_setup.py \
      --replace 'os.path.basename(data)[6:-4]' '"${darwin.apple_sdk.sdk.version}"'
  '';

  buildInputs = with darwin.apple_sdk.frameworks; [
    Foundation
    ScreenSaver
  ];

  propagatedBuildInputs = [
    pyobjc-core
    pyobjc-framework-Cocoa
  ];

  # clang-7: error: argument unused during compilation: '-fno-strict-overflow'
  hardeningDisable = [ "strictoverflow" ];

  dontUseSetuptoolsCheck = true;
  pythonImportcheck = [ "pyobjc-framework-ScreenSaver" ];

  meta = with stdenv.lib; {
    description = "Wrappers for the framework ScreenSaver on Mac OS X";
    homepage = "https://pythonhosted.org/pyobjc-framework-ScreenSaver/";
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = with maintainers; [ SuperSandro2000 ];
  };
}
