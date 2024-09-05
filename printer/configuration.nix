{ config, pkgs, lib, ... }:
let
  vars = import ./vars.nix;
in {
  networking.wireless = {
    enable = true;
    networks."${vars.wifi.ssid}".psk = vars.wifi.password;
    interfaces = [ "wlan0" ];
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
      zfs = super.zfs.overrideAttrs(_: {
         meta.platforms = [];
      });
    })
  ];

  environment.systemPackages = with pkgs; [
    nano curl iproute2 htop
    # for klipper:
    git gnumake python311 pkgsCross.avr.buildPackages.gcc avrdude
  ];

  services.openssh.enable = true;

  users = {
    mutableUsers = false;
    users."${vars.user}" = {
      isNormalUser = true;
      password = vars.password;
      openssh.authorizedKeys.keys = vars.authorizedKeys;
      extraGroups = [ "wheel" ];
    };
    users.klipper = {
      isNormalUser = true;
      group = "klipper";
    };
    groups.klipper = { };
  };
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "@wheel" ];

  hardware.enableRedistributableFirmware = true;

  networking.firewall = {
    allowedTCPPorts = [
      80
    ];
  };

  networking.hostName = vars.hostname;

  services.klipper = {
    enable = true;
    user = "klipper";
    group = "klipper";
    configFile = ./printer.cfg;
    # firmwares.ender3pro = {
    #   enable = true;
    #   serial = "/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0";
    #   enableKlipperFlash = true;
    #   configFile = ./atmega1284p.config;
    # };
  };

  services.moonraker = {
    enable = true;
    user = "klipper";
    group = "klipper";
    settings.authorization = {
      cors_domains = [
        "http://192.168.88.129"
      ];
      trusted_clients = [
        "127.0.0.1/32"
        "192.168.88.0/24"
      ];
    };
  };

  services.mainsail = {
    enable = true;
    hostName = vars.hostname;
    nginx = {
      basicAuth = vars.basicAuth;
    };
  };

  system.stateVersion = "23.11";
}
