{ pkgs ? import <nixpkgs> {}
, system ? builtins.currentSystem
, name ? "rpi"

, password
, authorized_keys ? [ "~/.ssh/id_rsa.pub" ]
, wifi_name ? null
, wifi_country ? "fi"
, wifi_password ? null
, vm_nameserver ? "1.1.1.1" }:
with pkgs;
with lib;
let
  specialArgs = {};
  qemuFlags = import <nixpkgs/nixos/lib/qemu-common.nix> { inherit pkgs lib; };

  armhf = import <nixpkgs> {
    crossSystem = (import <nixpkgs/lib>).systems.examples.raspberryPi;
  };

  qemuArmStatic = runCommand "qemu-arm-static" {
    src = builtins.fetchurl "https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/qemu-aarch64-static";
    dontUnpack = true;
  } ''
    mkdir -p $out/bin
    cp $src $out/bin/qemu-aarch64-static
    chmod +x $out/bin/qemu-aarch64-static
  '';

  packer-builder-arm-image = buildGoModule rec {
    name = "packer-builder-arm-image";
    src = fetchFromGitHub {
      owner = "solo-io";
      repo = "packer-builder-arm-image";
      rev = "v0.2.7";
      sha256 = "sha256-jH4eHkcbqgcJEyD8uBxyAIQskMdYKxUDGclNfrc4+S4=";
    };
    vendorSha256 = null;
  };

  buildHcl = writeText "build.pkr.hcl" ''
    source "arm-image" "raspios" {
      iso_url = "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64-lite.img.xz"
      iso_checksum = "bf982e56b0374712d93e185780d121e3f5c3d5e33052a95f72f9aed468d58fa7"
      output_filename = "./output-arm-image/raspios.img"
      target_image_size = 1024*1024*1024*2
      image_type = "raspberrypi"
      resolv-conf = "copy-host"
      additional_chroot_mounts = [
        ["bind", "/mnt/${name}", "/mnt/${name}"]
      ]
      qemu_binary = "qemu-aarch64-static"
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

        exec < /dev/${qemuFlags.qemuSerialDevice} &> /dev/${qemuFlags.qemuSerialDevice}

        trap "systemctl poweroff" EXIT INT QUIT TERM

        while ! ${netcat}/bin/nc -u -w0 ${vm_nameserver} 53 < /dev/null; do
          echo "Waiting for connection (${vm_nameserver}:53/UDP)!"
          sleep 1
        done

        export PACKER_PLUGIN_PATH=${packer-builder-arm-image}/bin
        cd /mnt/${name}/build
        ${packer}/bin/packer build ${buildHcl}
      '';
    };
    environment.systemPackages = [ multipath-tools qemuArmStatic ];
    networking.hostName = name;
    networking.nameservers = [ vm_nameserver ];
    networking.resolvconf.enable = true;
    virtualisation.libvirtd.enable = true;
    virtualisation.memorySize = 2048;
    virtualisation.cores = 2;
    virtualisation.msize = 10485760;
    #virtualisation.qemu.consoles = [ qemuFlags.qemuSerialDevice ];
    virtualisation.qemu.options = [
      "-nographic"
    ];
    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
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
          boot.readOnlyNixStore = false;
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

    '' + (optionalString (wifi_name != null) ''
      echo 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev' >>$PWD/mnt/overlay/boot/wpa_supplicant.conf
      echo 'country=${wifi_country}' >>$PWD/mnt/overlay/boot/wpa_supplicant.conf
      echo 'update_config=1' >>$PWD/mnt/overlay/boot/wpa_supplicant.conf
      wpa_passphrase "${wifi_name}" "${wifi_password}" | \
        sed -e 's/#.*$//' -e '/^$/d' >> $PWD/mnt/overlay/boot/wpa_supplicant.conf
    '') + ''

      mkdir -p $PWD/mnt/overlay/home/pi/.ssh
      rm -f $PWD/mnt/overlay/home/pi/.ssh/authorized_keys
      ${concatMapStringsSep "\n" (a: "cat ${a} >> $PWD/mnt/overlay/home/pi/.ssh/authorized_keys") authorized_keys}

      ${vm.config.system.build.vm}/bin/run-${name}-vm \
        -virtfs local,path=$PWD/mnt,security_model=none,mount_tag=${name}

      echo "Output image: ./mnt/build/output-arm-image/raspios.img"

      exit 0
    '';
  }
