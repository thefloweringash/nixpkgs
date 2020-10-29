{ stdenv, buildPythonPackage, pythonOlder, fetchPypi, darwin, python,
pyobjc-core, pyobjc-framework-Security }:

buildPythonPackage rec {
  pname = "pyobjc-framework-SecurityFoundation";
  version = "6.2.2";

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    sha256 = "18vs8b4c7hwwqizr8ys1daknnhjfskkjs9x7qyl5dmsil068yanx";
  };
  
  postPatch = ''
    # Hard code correct SDK version
    substituteInPlace pyobjc_setup.py \
      --replace 'os.path.basename(data)[6:-4]' '"${darwin.apple_sdk.sdk.version}"'
  '';

  buildInputs = [
  ] ++ (with darwin; [
  ] ++ (with apple_sdk.frameworks;[
  ]));

  propagatedBuildInputs = [
    pyobjc-core
    pyobjc-framework-Security
  ];

  # clang-7: error: argument unused during compilation: '-fno-strict-overflow'
  hardeningDisable = [ "strictoverflow" ];

  dontUseSetuptoolsCheck = true;
  pythonImportcheck = [ "pyobjc-framework-SecurityFoundation" ];

  meta = with stdenv.lib; {
    description = "Wrappers for the framework SecurityFoundation on Mac OS X";
    homepage = "https://pythonhosted.org/pyobjc-framework-SecurityFoundation/";
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = with maintainers; [ SuperSandro2000 ];
  };
}
