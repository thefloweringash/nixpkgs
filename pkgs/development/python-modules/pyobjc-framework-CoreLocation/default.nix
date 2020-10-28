{ stdenv, buildPythonPackage, pythonOlder, fetchPypi, darwin, python,
pyobjc-core, pyobjc-framework-Cocoa }:

buildPythonPackage rec {
  pname = "pyobjc-framework-CoreLocation";
  version = "6.2.2";

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    sha256 = "1gxqgqgfs19jr33dvq62ps4r8vl1b8vqiff71kyf236rm70j4xr3";
  };
  
  postPatch = ''
    # Hard code correct SDK version
    substituteInPlace pyobjc_setup.py \
      --replace 'os.path.basename(data)[6:-4]' '"${darwin.apple_sdk.sdk.version}"'
  '';

  buildInputs = [
  ] ++ (with darwin; [
  ] ++ (with apple_sdk.frameworks;[
    CoreLocation
    Foundation
  ]));

  propagatedBuildInputs = [
    pyobjc-core
    pyobjc-framework-Cocoa
  ];

  # clang-7: error: argument unused during compilation: '-fno-strict-overflow'
  hardeningDisable = [ "strictoverflow" ];

  # show test names instead of just dots
  setuptoolsCheckFlagsArray = [ "--verbosity=3" ];

  preCheck = ''
    # testConstants in PyObjCTest.test_cfsocket.TestSocket returns: Segmentation fault: 11
    export DYLD_FRAMEWORK_PATH=/System/Library/Frameworks
  '';

  meta = with stdenv.lib; {
    description = "Wrappers for the framework CoreLocation on Mac OS X";
    homepage = "https://pythonhosted.org/pyobjc-framework-CoreLocation/";
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = with maintainers; [ SuperSandro2000 ];
  };
}
