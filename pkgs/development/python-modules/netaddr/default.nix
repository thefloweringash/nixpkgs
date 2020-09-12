{ stdenv
, buildPythonPackage
, fetchPypi
, pytest
, fetchpatch
, glibcLocales
}:

buildPythonPackage rec {
  pname = "netaddr";
  version = "0.7.20";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0gkgfxjakfkagybjzrak29937sx6izmfif3yswaki4f3mvjm54nh";
  };

  LC_ALL = "en_US.UTF-8";
  checkInputs = [ glibcLocales pytest ];

  checkPhase = ''
    # fails on python3.7: https://github.com/drkjam/netaddr/issues/182
    py.test \
      -k 'not test_ip_splitter_remove_prefix_larger_than_input_range' \
      netaddr/tests
  '';

  meta = with stdenv.lib; {
    homepage = "https://github.com/drkjam/netaddr/";
    description = "A network address manipulation library for Python";
    license = licenses.mit;
  };

}
