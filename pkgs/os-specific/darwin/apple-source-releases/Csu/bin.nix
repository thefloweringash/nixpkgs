{ stdenvNoCC, fetchurl }:

stdenvNoCC.mkDeirvation {
  name = "Csu-bin";

  src = {
    # aarch64-darwin = fetchtarball {
    #  url = "https://s3.ap-northeast-1.amazonaws.com/nix-misc.cons.org.nz/apple-silicon-wip/Csu-bin.tar.gz";
    #  sha256 = "0000000000000000000000000000000000000000000000000000";
    # };
  }."${stdenvNoCC.hostPlatform.system}" or throw "Missing Csu-bin for cross compilation to ${stdenvNoCC.hostPlatform.system}";
};

