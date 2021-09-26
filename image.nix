{ pkgs ? import <nixpkgs> {}
, system ? builtins.currentSystem
, name ? "rpi"
, nameservers ? []

, password
, authorized_keys ? [ "~/.ssh/id_rsa.pub" ]
, wifi_name
, wifi_password }:
with pkgs;
with lib;
let
  specialArgs = {};
  qemuFlags = import <nixpkgs/nixos/lib/qemu-flags.nix> { inherit pkgs; };

  armhf = import <nixpkgs> {
    crossSystem = (import <nixpkgs/lib>).systems.examples.raspberryPi;
  };

  qemuArmStatic = runCommand "qemu-arm-static" {
    src = builtins.fetchurl https://github.com/multiarch/qemu-user-static/releases/download/v6.1.0-1/qemu-arm-static;
    dontUnpack = true;
  } ''
    mkdir -p $out/bin
    cp $src $out/bin/qemu-arm-static
    chmod +x $out/bin/qemu-arm-static
  '';

  packer-builder-arm-image = buildGoModule rec {
    name = "packer-builder-arm-image";
    src = fetchFromGitHub {
      owner = "solo-io";
      repo = "packer-builder-arm-image";
      rev = "920cc8d3c01eb3f3a3889ec63441924de963b858";
      sha256 = "0qdd22j6kflsydkxg37ijfb1qj7df67dvaq9zqyxqjq30yx1bxix";
    };
    vendorSha256 = null;
  };

  resolvConf = writeText "resolv.conf" ''
    ${concatMapStringsSep "\n" (i: "nameserver ${i}") nameservers}
  '';

  buildHcl = writeText "build.pkr.hcl" ''
    source "arm-image" "raspios" {
      iso_url = "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-05-28/2021-05-07-raspios-buster-armhf-lite.zip"
      iso_checksum = "c5dad159a2775c687e9281b1a0e586f7471690ae28f2f2282c90e7d59f64273c"
      output_filename = "./output-arm-image/raspios.img"
      target_image_size = 1024*1024*1024*2
      image_type = "raspberrypi"
      additional_chroot_mounts = [
        ["bind", "/mnt/${name}", "/mnt/${name}"],
        ${optionalString (nameservers != []) ''["bind", "${resolvConf}", "/etc/resolv.conf"]''}
      ]
    }
    build {
      sources = [
        "source.arm-image.raspios"
      ]
      provisioner "shell" {
        execute_command = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
        environment_vars = [ "PATH=/bin:/usr/bin" ]
        skip_clean = true
        inline = [
          "apt-get update",
          "apt-get upgrade -y",
          "/bin/bash -c 'echo -e \"${password}\n${password}\" | (passwd pi)'",
          "cp -vr /mnt/${name}/overlay/* /",
          "rm -rf /tmp/*"
        ]
      }
    }
  '';

  vm = buildVM {
    users.users.root.initialHashedPassword = mkForce "";
    services.journald.extraConfig = ''
      ForwardToConsole=yes
      MaxLevelConsole=debug
    '';
    systemd.services."serial-getty@${qemuFlags.qemuSerialDevice}".enable = false;
    systemd.services."serial-getty@hvc0".enable = false;
    systemd.services.build = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "network.target" "dev-${qemuFlags.qemuSerialDevice}.device" ];
      after = [ "network.target" "dev-${qemuFlags.qemuSerialDevice}.device" ];
      script = ''
        #!${stdenv.shell}
        set -e
        export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"
        mkdir -p /mnt/${name}
        mount -t 9p -o trans=virtio,msize=10485760 ${name} /mnt/${name}

        exec < /dev/${qemuFlags.qemuSerialDevice} > /dev/${qemuFlags.qemuSerialDevice}

        trap "systemctl poweroff" EXIT INT QUIT TERM

        export PACKER_PLUGIN_PATH=${packer-builder-arm-image}/bin
        cd /mnt/${name}/build
        ${packer}/bin/packer build ${buildHcl}
      '';
    };
    environment.systemPackages = [ multipath-tools qemuArmStatic ];
    networking.hostName = name;
    virtualisation.libvirtd.enable = true;
    virtualisation.memorySize = 2048;
    virtualisation.cores = 2;
    virtualisation.msize = 10485760;
    #virtualisation.qemu.consoles = [ qemuFlags.qemuSerialDevice ];
    virtualisation.qemu.options = [
      "-nographic"
    ];
    boot.binfmt.emulatedSystems = [ "armv6l-linux" ];
  };

  buildVM = configuration:
    import <nixpkgs/nixos/lib/eval-config.nix> {
      inherit system specialArgs;
      modules = [ configuration ];
      baseModules = (import <nixpkgs/nixos/modules/module-list.nix>) ++ [
        <nixpkgs/nixos/modules/virtualisation/qemu-vm.nix>
        { key = "no-manual"; documentation.nixos.enable = false; }
        { key = "no-revision";
          # Make the revision metadata constant, in order to avoid needless retesting.
          # The human version (e.g. 21.05-pre) is left as is, because it is useful
          # for external modules that test with e.g. nixosTest and rely on that
          # version number.
          config.system.nixos.revision = mkForce "constant-nixos-revision";
        }
        {
          key = "run-in-machine";
          nix.readOnlyStore = false;
          virtualisation.writableStore = false;
        }
      ];
    };
in
  mkShell {
    buildInputs = [ wpa_supplicant gnused coreutils ];
    shellHook = ''
      set -e
      mkdir -p $PWD/mnt/
      chmod -R +w $PWD/mnt
      rm -rf $PWD/mnt/overlay
      rm -rf $PWD/mnt/nix

      mkdir -p $PWD/mnt/{build,overlay}

      mkdir -p $PWD/mnt/overlay/boot
      touch $PWD/mnt/overlay/boot/ssh
      echo 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev' >>$PWD/mnt/overlay/boot/wpa_supplicant.conf
      echo 'country=fi' >>$PWD/mnt/overlay/boot/wpa_supplicant.conf
      echo 'update_config=1' >>$PWD/mnt/overlay/boot/wpa_supplicant.conf
      wpa_passphrase "${wifi_name}" "${wifi_password}" | \
        sed -e 's/#.*$//' -e '/^$/d' >> $PWD/mnt/overlay/boot/wpa_supplicant.conf

      mkdir -p $PWD/mnt/overlay/home/pi/.ssh
      rm -f $PWD/mnt/overlay/home/pi/.ssh/authorized_keys
      ${concatMapStringsSep "\n" (a: "cat ${a} >> $PWD/mnt/overlay/home/pi/.ssh/authorized_keys") authorized_keys}

      ${vm.config.system.build.vm}/bin/run-${name}-vm \
        -virtfs local,path=$PWD/mnt,security_model=none,mount_tag=${name}

      echo "Output image: ./mnt/build/output-arm-image/raspios.img"

      exit 0
    '';
  }
