{ stdenv, buildPythonPackage, pythonOlder, fetchPypi, darwin, python,
pyobjc-core, pyobjc-framework-Cocoa }:

buildPythonPackage rec {
  pname = "pyobjc-framework-AutomaticAssessmentConfiguration";
  version = "6.2.2";

  disabled = pythonOlder "3.6" ||
    (stdenv.lib.versionOlder "${darwin.apple_sdk.sdk.version}" "10.15") && throw "${pname}: requires apple_sdk.sdk 10.15";

  src = fetchPypi {
    inherit pname version;
    sha256 = "10ra8r177d57m9chq9dhq1wm9n34dvsf9skpfwhlpv1i7vr8i54v";
  };

  postPatch = ''
    # Hard code correct SDK version
    substituteInPlace pyobjc_setup.py \
      --replace 'os.path.basename(data)[6:-4]' '"${darwin.apple_sdk.sdk.version}"'
  '';

  propagatedBuildInputs = [
    pyobjc-core
    pyobjc-framework-Cocoa
  ];

  # clang-7: error: argument unused during compilation: '-fno-strict-overflow'
  hardeningDisable = [ "strictoverflow" ];

  dontUseSetuptoolsCheck = true;
  pythonImportsCheck = [ "AutomaticAssessmentConfiguration" ];

  meta = with stdenv.lib; {
    description = "Wrappers for the framework AutomaticAssessmentConfiguration on Mac OS X";
    homepage = "https://pythonhosted.org/pyobjc-framework-AutomaticAssessmentConfiguration/";
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = with maintainers; [ SuperSandro2000 ];
  };
}
