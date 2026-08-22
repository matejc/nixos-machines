{ config, lib, pkgs, modulesPath, ... }:
{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" "sdhci_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/b4da4a53-a864-427c-9b76-d0946f285801";
      fsType = "ext4";
    };

  fileSystems."/mnt/storage" = {
    device = "/dev/sda1";
    fsType = "ext4";
    options = [ "defaults" "nofail" "x-systemd.device-timeout=9" ];
  };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/FF43-D970";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/0bd0cb45-03bb-4cd7-b902-26f96b427044"; }
    ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
