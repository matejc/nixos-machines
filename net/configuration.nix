{ config, pkgs, lib, ... }:
let
  vars = import ./vars.nix;

  init-mongo-js = pkgs.writeText "init-mongo.js" ''
    db.getSiblingDB("unifi").createUser({user: "unifi", pwd: "${vars.mongo_pass}", roles: [{role: "dbOwner", db: "unifi"}]});
    db.getSiblingDB("unifi_stat").createUser({user: "unifi", pwd: "${vars.mongo_pass}", roles: [{role: "dbOwner", db: "unifi_stat"}]});
  '';
in {
  # networking.wireless = {
  #   enable = true;
  #   networks."${vars.SSID}".psk = vars.SSIDpassword;
  #   interfaces = [ vars.interface ];
  # };

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

  environment.systemPackages = with pkgs; [ nano curl iproute2 htop ];

  services.openssh.enable = true;

  users = {
    mutableUsers = false;
    users."${vars.user}" = {
      isNormalUser = true;
      password = vars.password;
      openssh.authorizedKeys.keys = vars.authorizedKeys;
      extraGroups = [ "wheel" ];
    };
  };
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "@wheel" ];

  hardware.enableRedistributableFirmware = true;

  networking.firewall = {
    allowedTCPPorts = [
      80 53
      8080  # Port for UAP to inform controller.
      8880  # Port for HTTP portal redirect, if guest portal is enabled.
      8843  # Port for HTTPS portal redirect, ditto.
      6789  # Port for UniFi mobile speed test.
      8443
    ];
    allowedUDPPorts = [
      53
      3478  # UDP port used for STUN.
      10001 # UDP port used for device discovery.
    ];
  };

  networking.nameservers = vars.nameservers;
  networking.hostName = vars.hostname;

  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
    autoPrune.enable = true;
  };

  services.upaas = {
    enable = true;
    plugins = false;
    configuration = {
      stack = {
        pihole = {
          enable = true;
          autostart = true;
          user = "pihole";
          directory = "/var/lib/pihole";
          compose = {
            services.pihole = {
              image = "pihole/pihole:2024.07.0";
              environment = {
                TZ = "Europe/Helsinki";
                WEBPASSWORD = vars.pihole_webpassword;
              };
              volumes = [
                "/var/lib/pihole/pihole:/etc/pihole"
                "/var/lib/pihole/dnsmasq.d:/etc/dnsmasq.d"
                "/var/lib/pihole/log:/var/log/pihole"
              ];
              network_mode = "host";
            };
          };
        };
        unifi = {
          enable = true;
          autostart = true;
          user = "unifi";
          directory = "/var/lib/unifi";
          compose = {
            services.unifi = {
              image = "lscr.io/linuxserver/unifi-network-application:8.3.32-ls56";
              environment = {
                TZ = "Europe/Helsinki";
                PUID = "${toString config.users.users.unifi.uid}";
                PGID = "${toString config.users.groups.unifi.gid}";
                MONGO_USER = "unifi";
                MONGO_PASS = vars.mongo_pass;
                MONGO_HOST = "127.0.0.1";
                MONGO_PORT = "27017";
                MONGO_DBNAME = "unifi";
              };
              volumes = [
                "/var/lib/unifi/config:/config"
              ];
              network_mode = "host";
            };
            services.mongo = {
              image = "mongo:4.4.18";
              volumes = [
                "/var/lib/unifi/db:/data/db"
                "${init-mongo-js}:/docker-entrypoint-initdb.d/init-mongo.js:ro"
              ];
              network_mode = "host";
            };
          };
        };
      };
    };
  };

  users.users.pihole = {
    isNormalUser = true;
    createHome = true;
    home = "/var/lib/pihole";
    extraGroups = [ "docker" ];
    group = "pihole";
  };
  users.groups.pihole = {};

  users.users.unifi = {
    createHome = true;
    home = "/var/lib/unifi";
    extraGroups = [ "docker" ];
    uid = 911;
    group = "unifi";
  };
  users.groups.unifi.gid = 911;

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "23.11";
}
