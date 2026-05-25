{ modulesPath, config, pkgs, lib, ... }:
let
  # https://wiki.gentoo.org/wiki/GRUB_on_Open_Firmware_(PowerPC)
  # Merged with nixos/modules/installer/cd-dvd/iso-image.nix

  # Builds a single menu entry
  menuBuilderGrub2 =
    {
      name,
      class,
      image,
      params,
      initrd,
    }:
    ''
      menuentry '${name}' --class ${class} {
        # Fallback to UEFI console for boot, efifb sometimes has difficulties.
        terminal_output console

        linux ${image} \''${isoboot} ${params}
        initrd ${initrd}
      }
    '';

  # Builds all menu entries
  buildMenuGrub2 =
    {
      cfg ? config,
      params ? [ ],
    }:
    let
      menuConfig = {
        name = lib.concatStrings [
          cfg.isoImage.prependToMenuLabel
          cfg.system.nixos.distroName
          " "
          cfg.system.nixos.label
          cfg.isoImage.appendToMenuLabel
          (lib.optionalString (cfg.isoImage.configurationName != null) (" " + cfg.isoImage.configurationName))
        ];
        params = "init=${cfg.system.build.toplevel}/init ${toString cfg.boot.kernelParams} ${toString params}";
        image = "/boot/${cfg.boot.kernelPackages.kernel + "/" + cfg.system.boot.loader.kernelFile}";
        initrd = "/boot/${cfg.system.build.initialRamdisk + "/" + cfg.system.boot.loader.initrdFile}";
        class = "installer";
      };
    in
    ''
      ${lib.optionalString cfg.isoImage.showConfiguration (menuBuilderGrub2 menuConfig)}
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          specName:
          { configuration, ... }:
          buildMenuGrub2 {
            cfg = configuration;
            inherit params;
          }
        ) cfg.specialisation
      )}
    '';

  grubImage = pkgs.runCommand "grub-image" {
    nativeBuildInputs = [ pkgs.buildPackages.grub2 ];
    grubConfig =
      let
        cfg = config;
        # image = "/boot/${cfg.boot.kernelPackages.kernel + "/" + cfg.system.boot.loader.kernelFile}";
        # initrd = "/boot/${cfg.system.build.initialRamdisk + "/" + cfg.system.boot.loader.initrdFile}";
      in
          # ${buildMenuGrub2 { }}
        ''
          set timeout=5
          echo "Searching for root"
          search --set=root --file /${cfg.system.boot.loader.kernelFile}
          echo "root=$root"
          echo "Loading kernel"
          linux /${cfg.system.boot.loader.kernelFile} \''${isoboot} ${toString cfg.boot.kernelParams}
          echo "Loading initrd"
          initrd /${cfg.system.boot.loader.initrdFile}
          echo "Booting"
          boot
        '';
    passAsFile = [ "grubConfig" ];
  }
  ''
    mkdir -p $out/grub

    MODULES=(
      # Basic modules for filesystems and partition schemes
      "fat"
      "ext2"
      "iso9660"
      "part_gpt"
      "part_msdos"

      # Basic stuff
      "normal"
      "boot"
      "linux"
      "configfile"
      "loopback"
      "halt"

      # System commands
      "search"
      "search_label"
      "search_fs_uuid"
      "search_fs_file"
      "echo"

      # Graphical mode stuff
      "gfxmenu"
      "gfxterm"
      "gfxterm_background"
      "gfxterm_menu"
      "test"
      "loadenv"
      "all_video"
      "videoinfo"

      # PowerMac specific things
      "part_apple"
      "hfs"
      "hfsplus"
      "hfspluscomp"
    )

    grub-mkimage \
      --directory=${pkgs.grub2}/lib/grub/${pkgs.grub2.grubTarget} \
      --prefix=/grub \
      --output $out/grub/grub.img \
      --format=powerpc-ieee1275 \
      --config=$grubConfigPath \
      ''${MODULES[@]}

    cp ${pkgs.grub2}/share/grub/unicode.pf2 $out/grub/
  '';
in
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  boot.kernelParams = [ "nomodeset" ];
  # boot.initrd.kernelModules = [ "nouveau" ]; 1.3gb!!!

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
            grub2 = prev.grub2.override { ieee1275Support = true; efiSupport = false; };
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
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPackages = pkgs.linuxPackages_5_15;


  # 5.10 failure message:
  #   BOOTCC  arch/powerpc/boot/ofconsole.o
  # In file included from ../arch/powerpc/boot/devtree.c:12:
  # ../arch/powerpc/boot/types.h:43:13: error: 'bool' cannot be defined via 'typedef'
  #    43 | typedef int bool;
  #       |             ^~~~
  # ../arch/powerpc/boot/types.h:43:13: note: 'bool' is a keyword with '-std=c23' onwards
  # In file included from ../arch/powerpc/boot/ops.h:15,
  #                  from ../arch/powerpc/boot/cuboot.c:12:
  # ../arch/powerpc/boot/types.h:43:13: error: 'bool' cannot be defined via 'typedef'
  #    43 | typedef int bool;
  #       |             ^~~~
  # ../arch/powerpc/boot/types.h:43:13: note: 'bool' is a keyword with '-std=c23' onwards
  # ../arch/powerpc/boot/types.h:43:1: warning: useless type name in empty declaration
  #    43 | typedef int bool;
  #       | ^~~~~~~
  # ../arch/powerpc/boot/types.h:43:1: warning: useless type name in empty declaration
  #    43 | typedef int bool;
  #       | ^~~~~~~
  # make[2]: *** [../arch/powerpc/boot/Makefile:216: arch/powerpc/boot/cuboot.o] Error 1
  # make[2]: *** Waiting for unfinished jobs....

  # Special IEEE1275 boot
  isoImage.makeEfiBootable = lib.mkForce false;
  isoImage.makeBiosBootable = lib.mkForce false;

  # gobject-introspection is a rats nest
  networking.networkmanager.enable = lib.mkForce false;
  networking.modemmanager.enable = lib.mkForce false;

  # Super short, for ext2
  isoImage.volumeID = "nixos";

  isoImage.contents =
    [
      {
        source = "${grubImage}/grub";
        target = "/grub";
      }
    ];

  boot.loader.grub.efiSupport = false;

  boot.supportedFilesystems = [ "hfs" ];

  system.build.grubImage = grubImage;

  system.build.usbboot = pkgs.symlinkJoin {
    name = "usbboot";
    paths = [
      grubImage
      config.boot.kernelPackages.kernel
      config.system.build.initialRamdisk
    ];
  };
}
