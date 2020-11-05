{ stdenv, buildPythonPackage, pythonOlder, fetchPypi, darwin, python,
pyobjc-core, pyobjc-framework-Cocoa, pyobjc-framework-CoreMedia, pyobjc-framework-Quartz }:

# This file is generated by pkgs/development/python-modules/pyobjc/update.sh. Please don't modify it directly.
# If you need help please contact a maintainer of pyobjc.

buildPythonPackage rec {
  pname = "pyobjc-framework-VideoToolbox";
  version = "6.2.2";

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    sha256 = "11jyz43c8ciylbrznzg3lz18am8vyxywhd1bi0w2x34y7zygqq5f";
  };

  postPatch = ''
    # Hard code correct SDK version
    substituteInPlace pyobjc_setup.py \
      --replace 'os.path.basename(data)[6:-4]' '"${darwin.apple_sdk.sdk.version}"'
  '';

  buildInputs = with darwin.apple_sdk.frameworks; [
    Foundation
    VideoToolbox
  ];

  propagatedBuildInputs = [
    pyobjc-core
    pyobjc-framework-Cocoa
    pyobjc-framework-CoreMedia
    pyobjc-framework-Quartz
  ];

  # clang-7: error: argument unused during compilation: '-fno-strict-overflow'
  hardeningDisable = [ "strictoverflow" ];

  # show test names instead of just dots
  checkPhase = ''
    runHook preCheck

    ${python.interpreter} setup.py test --verbosity=3

    runHook postCheck
  '';

  preCheck = ''
    # testConstants in PyObjCTest.test_cfsocket.TestSocket returns: Segmentation fault: 11
    export DYLD_FRAMEWORK_PATH=/System/Library/Frameworks
  '';

  meta = with stdenv.lib; {
    description = "Wrappers for the framework VideoToolbox on Mac OS X";
    homepage = "https://pythonhosted.org/pyobjc-framework-VideoToolbox/";
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = with maintainers; [ SuperSandro2000 ];
  };
}
