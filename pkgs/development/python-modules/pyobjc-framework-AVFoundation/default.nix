{ stdenv, buildPythonPackage, pythonOlder, fetchPypi, darwin, python,
pyobjc-core, pyobjc-framework-Cocoa, pyobjc-framework-CoreMedia, pyobjc-framework-Quartz }:

buildPythonPackage rec {
  pname = "pyobjc-framework-AVFoundation";
  version = "6.2.2";

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    sha256 = "1yz2vw7gzb3q511hnfdrv0dxchqalcgqi4zvnxq0g44zp5qpqd4x";
  };
  
  postPatch = ''
    # Hard code correct SDK version
    substituteInPlace pyobjc_setup.py \
      --replace 'os.path.basename(data)[6:-4]' '"${darwin.apple_sdk.sdk.version}"'
  '';

  buildInputs = [
  ] ++ (with darwin; [
  ] ++ (with apple_sdk.frameworks;[
    AVFoundation
    Foundation
  ]));

  propagatedBuildInputs = [
    pyobjc-core
    pyobjc-framework-Cocoa
    pyobjc-framework-CoreMedia
    pyobjc-framework-Quartz
  ];

  # clang-7: error: argument unused during compilation: '-fno-strict-overflow'
  hardeningDisable = [ "strictoverflow" ];

  # show test names instead of just dots
  setuptoolsCheckFlagsArray = [ "--verbosity=3" ];

  preCheck = ''
    # testConstants in PyObjCTest.test_cfsocket.TestSocket returns: Segmentation fault: 11
    export DYLD_FRAMEWORK_PATH=/System/Library/Frameworks
    # Remove Test which is probably missing a sdk check
    substituteInPlace PyObjCTest/test_avcapturedevice.py \
      --replace 'def testMissingConstants(self):' 'def disabled_testMissingConstants(self):'
  '';

  meta = with stdenv.lib; {
    description = "Wrappers for the framework AVFoundation on Mac OS X";
    homepage = "https://pythonhosted.org/pyobjc-framework-AVFoundation/";
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = with maintainers; [ SuperSandro2000 ];
  };
}
