{ config, pkgs, lib, ... }:
{
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
      fsType = "ext4";
    };
    "/mnt/storage" = {
      device = "/dev/sda1";
      fsType = "ext4";
      options = [ "defaults" "nofail" "x-systemd.device-timeout=9" ];
    };
  };
}
