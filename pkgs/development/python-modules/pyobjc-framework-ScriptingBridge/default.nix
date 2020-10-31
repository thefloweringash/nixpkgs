{ stdenv, buildPythonPackage, pythonOlder, fetchPypi, darwin, python,
pyobjc-core, pyobjc-framework-Cocoa }:

buildPythonPackage rec {
  pname = "pyobjc-framework-ScriptingBridge";
  version = "6.2.2";

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0dy0fjcwvd9p3dj2fpvm3iwjrwz4alnmm5ffmymyp1k63wsmkxpk";
  };
  
  postPatch = ''
    # Hard code correct SDK version
    substituteInPlace pyobjc_setup.py \
      --replace 'os.path.basename(data)[6:-4]' '"${darwin.apple_sdk.sdk.version}"'
  '';

  buildInputs = [
  ] ++ (with darwin; [
  ] ++ (with apple_sdk.frameworks;[
    Foundation
    ScriptingBridge
  ]));

  propagatedBuildInputs = [
    pyobjc-core
    pyobjc-framework-Cocoa
  ];

  # clang-7: error: argument unused during compilation: '-fno-strict-overflow'
  hardeningDisable = [ "strictoverflow" ];

  dontUseSetuptoolsCheck = true;
  pythonImportcheck = [ "pyobjc-framework-ScriptingBridge" ];

  meta = with stdenv.lib; {
    description = "Wrappers for the framework ScriptingBridge on Mac OS X";
    homepage = "https://pythonhosted.org/pyobjc-framework-ScriptingBridge/";
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = with maintainers; [ SuperSandro2000 ];
  };
}
