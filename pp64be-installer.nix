{ modulesPath, pkgs, lib, ... }: {

  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  nixpkgs = {
    hostPlatform = "powerpc64-linux";
    buildPlatform = "x86_64-linux";
    config.allowUnsupportedSystem = true;

    overlays =
      let
        withoutIntrospection = pkg: pkg.override { withIntrospection = false; };
      in
        [
          (final: prev: {
            grub = prev.grub.override { ieee1275support = true; efiSupport = false; };
            grub2_efi = final.emptyDirectory; # unconditional reference in iso-image.nix, in system.extraDependencies

            # Emulation of gobject-introspection is somtimes broken for reasons I don't understand.
            #  /nix/store/7a04jzcnpx23agv8i0ybj9455ckw5vzd-qemu-user-10.2.2/bin/qemu-ppc64: error while loading shared libraries: /nix/store/plggjr2xl3xg1l9b6gy9nbpvdad2plak-glib-powerpc64-unknown-linux-gnuabielfv1-2.88.1/lib/libglib-2.0.so.0: ELF file data encoding not little-endian
            libgudev = withoutIntrospection prev.libgudev;
            libmbim = withoutIntrospection prev.libmbim;
            libqrtr-glib = withoutIntrospection prev.libqrtr-glib;
            libqmi = withoutIntrospection prev.libqmi;
            polkit = withoutIntrospection prev.polkit;
            bluez = prev.bluez.override { installTests = false; }; # also introspection
            modemmanager = withoutIntrospection prev.modemmanager;
          })
        ];
  };

  # Currently LTS fails
  #
  # ../arch/powerpc/platforms/pseries/papr-hvpipe.c: In function 'papr_hvpipe_dev_create_handle':
  # ../arch/powerpc/platforms/pseries/papr-hvpipe.c:513:9: error: implicit declaration of function 'FD_PREPARE' [-Wimplicit-function-declaration]
  #   513 |         FD_PREPARE(fdf, O_RDONLY | O_CLOEXEC,
  #       |         ^~~~~~~~~~
  # ../arch/powerpc/platforms/pseries/papr-hvpipe.c:513:20: error: 'fdf' undeclared (first use in this function); did you mean 'fd'?
  #   513 |         FD_PREPARE(fdf, O_RDONLY | O_CLOEXEC,
  #       |                    ^~~
  #       |                    fd
  # ../arch/powerpc/platforms/pseries/papr-hvpipe.c:513:20: note: each undeclared identifier is reported only once for each function it appears in
  # ../arch/powerpc/platforms/pseries/papr-hvpipe.c:532:16: error: implicit declaration of function 'fd_publish' [-Wimplicit-function-declaration]
  #   532 |         return fd_publish(fdf);
  #       |                ^~~~~~~~~~
  # make[5]: *** [../scripts/Makefile.build:287: arch/powerpc/platforms/pseries/papr-hvpipe.o] Error 1
  # make[4]: *** [../scripts/Makefile.build:544: arch/powerpc/platforms/pseries] Error 2
  # make[4]: *** Waiting for unfinished jobs....
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Special IEEE1275 boot
  isoImage.makeEfiBootable = lib.mkForce false;
  isoImage.makeBiosBootable = lib.mkForce false;

  # gobject-introspection is a rats nest
  networking.networkmanager.enable = lib.mkForce false;
  networking.modemmanager.enable = lib.mkForce false;

  boot.loader.grub.efiSupport = false;
}
