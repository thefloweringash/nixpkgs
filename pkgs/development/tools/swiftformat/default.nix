{ stdenv, lib, fetchFromGitHub, swift, swiftpm }:

stdenv.mkDerivation rec {
  pname = "swiftformat";
  version = "0.51.15";

  src = fetchFromGitHub {
    owner = "nicklockwood";
    repo = "SwiftFormat";
    rev = version;
    sha256 = "sha256-cxW5L2x4HOfDxyx+lm8ek2DWwseu6KmTcBLCRw9HXSE=";
  };

  nativeBuildInputs = [ swift swiftpm ];

  swiftpmFlags = [ "--product swiftformat" ];

  installPhase = ''
    binPath="$(swiftpmBinPath)"
    install -D -m 0555 $binPath/swiftformat $out/bin/swiftformat
  '';

  meta = with lib; {
    description = "A code formatting and linting tool for Swift";
    homepage = "https://github.com/nicklockwood/SwiftFormat";
    license = licenses.mit;
    maintainers = [ maintainers.bdesham ];
    hydraPlatforms = [];
  };
}
