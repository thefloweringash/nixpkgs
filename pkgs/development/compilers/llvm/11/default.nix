{ lowPrio, newScope, pkgs, lib, stdenv, cmake, gccForLibs
, libxml2, python3, isl, fetchurl, overrideCC, wrapCCWith, wrapBintoolsWith
, buildPackages
, buildLlvmTools # tools, but from the previous stage, for cross
, targetLlvmLibraries # libraries, but from the next stage, for cross
}:

let
  release_version = "11.0.1";
  candidate = ""; # empty or "rcN"
  dash-candidate = lib.optionalString (candidate != "") "-${candidate}";
  version = "${release_version}${dash-candidate}"; # differentiating these (variables) is important for RCs
  targetConfig = stdenv.targetPlatform.config;

  fetch = name: sha256: fetchurl {
    url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-${version}/${name}-${release_version}${candidate}.src.tar.xz";
    inherit sha256;
  };

  clang-tools-extra_src = fetch "clang-tools-extra" "1j8n6n4l54k2lrdxh266y1fl4z8vy5dc76wsf0csk5n3ikfi38ic";

  tools = lib.makeExtensible (tools: let
    callPackage = newScope (tools // { inherit stdenv cmake libxml2 python3 isl release_version version fetch; });
    mkExtraBuildCommands = cc: ''
      rsrc="$out/resource-root"
      mkdir "$rsrc"
      ln -s "${cc}/lib/clang/${release_version}/include" "$rsrc"
      ln -s "${targetLlvmLibraries.compiler-rt.out}/lib" "$rsrc/lib"
      ln -s "${targetLlvmLibraries.compiler-rt.out}/share" "$rsrc/share"
      echo "-resource-dir=$rsrc" >> $out/nix-support/cc-cflags
    '';
  in {

    llvm = callPackage ./llvm.nix { };

    clang-unwrapped = callPackage ./clang {
      inherit (tools) lld;
      inherit clang-tools-extra_src;
    };

    # disabled until recommonmark supports sphinx 3
    #Llvm-manpages = lowPrio (tools.llvm.override {
    #  enableManpages = true;
    #  python3 = pkgs.python3;  # don't use python-boot
    #});

    clang-manpages = lowPrio (tools.clang-unwrapped.override {
      enableManpages = true;
      python3 = pkgs.python3;  # don't use python-boot
    });

    # disabled until recommonmark supports sphinx 3
    # lldb-manpages = lowPrio (tools.lldb.override {
    #   enableManpages = true;
    #   python3 = pkgs.python3;  # don't use python-boot
    # });

    libclang = tools.clang-unwrapped.lib;

    clang = if stdenv.cc.isGNU then tools.libstdcxxClang else tools.libcxxClang;

    libstdcxxClang = wrapCCWith rec {
      cc = tools.clang-unwrapped;
      # libstdcxx is taken from gcc in an ad-hoc way in cc-wrapper.
      libcxx = null;
      extraPackages = [
        targetLlvmLibraries.compiler-rt
      ];
      extraBuildCommands = mkExtraBuildCommands cc;
    };

    libcxxClang = wrapCCWith rec {
      cc = tools.clang-unwrapped;
      libcxx = targetLlvmLibraries.libcxx;
      extraPackages = [
        targetLlvmLibraries.libcxxabi
        targetLlvmLibraries.compiler-rt
      ];
      extraBuildCommands = mkExtraBuildCommands cc;
    };

    lld = callPackage ./lld.nix {};

    lldb = callPackage ./lldb.nix {};

    # Below, is the LLVM bootstrapping logic. It handles building a
    # fully LLVM toolchain from scratch. No GCC toolchain should be
    # pulled in. As a consequence, it is very quick to build different
    # targets provided by LLVM and we can also build for what GCC
    # doesn’t support like LLVM. Probably we should move to some other
    # file.

    bintools = callPackage ./bintools.nix {};

    lldClang = wrapCCWith rec {
      cc = tools.clang-unwrapped;
      libcxx = targetLlvmLibraries.libcxx;
      bintools = wrapBintoolsWith {
        inherit (tools) bintools;
      };
      extraPackages = [
        targetLlvmLibraries.libcxxabi
        targetLlvmLibraries.compiler-rt
      ] ++ lib.optionals (!stdenv.targetPlatform.isWasm) [
        targetLlvmLibraries.libunwind
      ];
      extraBuildCommands = ''
        echo "-rtlib=compiler-rt -Wno-unused-command-line-argument" >> $out/nix-support/cc-cflags
        echo "-B${targetLlvmLibraries.compiler-rt}/lib" >> $out/nix-support/cc-cflags
      '' + lib.optionalString (!stdenv.targetPlatform.isWasm) ''
        echo "--unwindlib=libunwind" >> $out/nix-support/cc-cflags
      '' + lib.optionalString stdenv.targetPlatform.isWasm ''
        echo "-fno-exceptions" >> $out/nix-support/cc-cflags
      '' + mkExtraBuildCommands cc;
    };

    lldClangNoLibcxx = wrapCCWith rec {
      cc = tools.clang-unwrapped;
      libcxx = null;
      bintools = wrapBintoolsWith {
        inherit (tools) bintools;
      };
      extraPackages = [
        targetLlvmLibraries.compiler-rt
      ];
      extraBuildCommands = ''
        echo "-rtlib=compiler-rt" >> $out/nix-support/cc-cflags
        echo "-B${targetLlvmLibraries.compiler-rt}/lib" >> $out/nix-support/cc-cflags
        echo "-nostdlib++" >> $out/nix-support/cc-cflags
      '' + mkExtraBuildCommands cc;
    };

    cctoolsClangNoLibcxx = wrapCCWith rec {
      cc = tools.clang-unwrapped;
      libcxx = null;
      gccForLibs = null; # prevent cc-wrapper from taking libs from gcc
      bintools = wrapBintoolsWith {
        bintools = pkgs.darwin.binutils-unwrapped;
        inherit (pkgs.darwin) postLinkSignHook sigtool;
      };
      extraPackages = [
        targetLlvmLibraries.compiler-rt
      ];
      extraBuildCommands = ''
        echo "-rtlib=compiler-rt" >> $out/nix-support/cc-cflags
        echo "-B${targetLlvmLibraries.compiler-rt}/lib" >> $out/nix-support/cc-cflags
        echo "-nostdlib++" >> $out/nix-support/cc-cflags
      '' + mkExtraBuildCommands cc;
    };

    lldClangNoLibc = wrapCCWith rec {
      cc = tools.clang-unwrapped;
      libcxx = null;
      bintools = wrapBintoolsWith {
        inherit (tools) bintools;
        libc = null;
      };
      extraPackages = [
        targetLlvmLibraries.compiler-rt
      ];
      extraBuildCommands = ''
        echo "-rtlib=compiler-rt" >> $out/nix-support/cc-cflags
        echo "-B${targetLlvmLibraries.compiler-rt}/lib" >> $out/nix-support/cc-cflags
      '' + mkExtraBuildCommands cc;
    };

    lldClangNoCompilerRt = wrapCCWith {
      cc = tools.clang-unwrapped;
      libcxx = null;
      bintools = wrapBintoolsWith {
        inherit (tools) bintools;
        libc = null;
      };
      extraPackages = [ ];
      extraBuildCommands = ''
        echo "-nostartfiles" >> $out/nix-support/cc-cflags
      '';
    };

    cctoolsClangNoCompilerRt = wrapCCWith {
      cc = tools.clang-unwrapped;
      libcxx = null;
      gccForLibs = null; # prevent cc-wrapper from taking libs from gcc
      bintools = wrapBintoolsWith {
        bintools = pkgs.darwin.binutils-unwrapped;
        # XXX: this is a departure from lldClangNoCompilerRt
        # Required for TargetConditionals.h header
        # libc = null; -- only ok with pure libSystem
        inherit (pkgs.darwin) postLinkSignHook sigtool;
      };
      extraPackages = [ ];
      extraBuildCommands = ''
        echo "-nostartfiles" >> $out/nix-support/cc-cflags
      '';
    };
  });

  libraries = lib.makeExtensible (libraries: let
    callPackage = newScope (libraries // buildLlvmTools // { inherit stdenv cmake libxml2 python3 isl release_version version fetch; });
  in {

    compiler-rt = let
      stdenv_ =
        if stdenv.hostPlatform.useLLVM or false
          then overrideCC stdenv buildLlvmTools.lldClangNoCompilerRt
        else if stdenv.hostPlatform.isDarwin && (stdenv.hostPlatform != stdenv.buildPlatform)
          then overrideCC stdenv buildLlvmTools.cctoolsClangNoCompilerRt
        else null;
    in callPackage ./compiler-rt.nix ({} //
      (lib.optionalAttrs (stdenv_ != null) {
        stdenv = stdenv_;
      }));

    stdenv = overrideCC stdenv buildLlvmTools.clang;

    libcxxStdenv = overrideCC stdenv buildLlvmTools.libcxxClang;

    libcxx = let
      stdenv_ =
        if stdenv.hostPlatform.useLLVM or false
          then overrideCC stdenv buildLlvmTools.lldClangNoLibcxx
        else if stdenv.hostPlatform.isDarwin && (stdenv.hostPlatform != stdenv.buildPlatform)
          then overrideCC stdenv buildLlvmTools.cctoolsClangNoLibcxx
        else null;
    in callPackage ./libc++ ({} //
      (lib.optionalAttrs (stdenv_ != null) {
        stdenv = stdenv_;
      }));

    libcxxabi = let
      stdenv_ =
        if stdenv.hostPlatform.useLLVM or false
          then overrideCC stdenv buildLlvmTools.lldClangNoLibcxx
        else if stdenv.hostPlatform.isDarwin && (stdenv.hostPlatform != stdenv.buildPlatform)
          then overrideCC stdenv buildLlvmTools.cctoolsClangNoLibcxx
        else null;
    in callPackage ./libc++abi.nix ({} //
      (lib.optionalAttrs (stdenv_ != null) {
        stdenv = stdenv_;
        libunwind = libraries.libunwind;
      }));

    openmp = callPackage ./openmp.nix {};

    libunwind = let
      stdenv_ =
        if stdenv.hostPlatform.useLLVM or false
          then overrideCC stdenv buildLlvmTools.lldClangNoLibcxx
        else if stdenv.hostPlatform.isDarwin && (stdenv.hostPlatform != stdenv.buildPlatform)
          then overrideCC stdenv buildLlvmTools.cctoolsClangNoLibcxx
        else null;
    in callPackage ./libunwind.nix ({} //
      (lib.optionalAttrs (stdenv_ != null) {
        stdenv = stdenv_;
      }));

  });

in { inherit tools libraries; } // libraries // tools
