{ config, pkgs, lib, inputs, ... }:
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

  environment.systemPackages = with pkgs; [ nano curl iproute2 htop ncdu ];

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

  nix = {
    channel.enable = false;
    settings = {
      nix-path = "nixpkgs=${inputs.nixpkgs}";
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "@wheel" ];
    };
    gc = {
      automatic = true;
      dates = "daily";
    };
  };

  hardware.enableRedistributableFirmware = true;

  networking.firewall = {
    allowedTCPPorts = [
      443 53
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
              image = "pihole/pihole:2025.08.0";
              environment = {
                TZ = "Europe/Helsinki";
                FTLCONF_webserver_api_password = vars.pihole_webpassword;
                FTLCONF_webserver_port = "443s";
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
              image = "lscr.io/linuxserver/unifi-network-application:9.3.45-ls100";
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
                "/var/lib/unifi/config_4:/config"
              ];
              network_mode = "host";
            };
            services.mongo = {
              image = "mongo:4.4.18";
              volumes = [
                "/var/lib/unifi/db_4:/data/db"
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

/*
  system.activationScripts.grafana-agent-read-pihole.text = ''
    chmod o+rx /var/lib/pihole
    chmod o+rx /var/lib/pihole/log
    chmod o+r /var/lib/pihole/log/pihole.log*
  '';
*/

/*
  systemd.services."prometheus-pihole-exporter" = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig.Restart = "always";
    serviceConfig.PrivateTmp = true;
    serviceConfig.WorkingDirectory = /tmp;
    serviceConfig.DynamicUser = true;
    serviceConfig.User = "pihole-exporter";
    serviceConfig.Group = "pihole-exporter";
    # Hardening
    serviceConfig.CapabilityBoundingSet = [ "" ];
    serviceConfig.DeviceAllow = [ "" ];
    serviceConfig.LockPersonality = true;
    serviceConfig.MemoryDenyWriteExecute = true;
    serviceConfig.NoNewPrivileges = true;
    serviceConfig.PrivateDevices = true;
    serviceConfig.ProtectClock = true;
    serviceConfig.ProtectControlGroups = true;
    serviceConfig.ProtectHome = true;
    serviceConfig.ProtectHostname = true;
    serviceConfig.ProtectKernelLogs = true;
    serviceConfig.ProtectKernelModules = true;
    serviceConfig.ProtectKernelTunables = true;
    serviceConfig.ProtectSystem = "strict";
    serviceConfig.RemoveIPC = true;
    serviceConfig.RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
    serviceConfig.RestrictNamespaces = true;
    serviceConfig.RestrictRealtime = true;
    serviceConfig.RestrictSUIDSGID = true;
    serviceConfig.SystemCallArchitectures = "native";
    serviceConfig.UMask = "0077";
    serviceConfig.ExecStart = ''
      ${pkgs.prometheus-pihole-exporter}/bin/pihole-exporter \
        -pihole_password "${vars.pihole_webpassword}" \
        -pihole_hostname 127.0.0.1 \
        -pihole_port 80 \
        -pihole_protocol http \
        -port 9617 \
        -timeout 5s
    '';
  };
*/
/*
  services.grafana-agent.enable = true;
  services.grafana-agent.settings = {
*/
/*
    metrics = {
      configs = [{
        name = "default";
        scrape_configs = [{
          job_name = "pihole";
          static_configs = [{
            targets = [ "localhost:9617" ];
            labels = {
              service = "pihole-exporter";
              node = "net";
            };
          }];
        }];
      }];
      global = {
        remote_write = [{
          url = vars.prometheus_push_url;
        }];
      };
      wal_directory = "/tmp/wal";
    };
*/
/*
    logs = {
      configs = [{
        clients = [{
          url = vars.loki_push_url;
        }];
        name = "pihole";
        scrape_configs = [{
          job_name = "pihole_log";
          static_configs = [{
            targets = [ "localhost" ];
            labels = {
              instance = config.networking.hostName;
              job = "pihole_log";
              __path__ = "/var/lib/pihole/log/pihole.log*";
              __path_exclude__ = "/var/lib/pihole/log/pihole.log*gz";
            };
          }];
          pipeline_stages = [{ match = {
            selector = ''{job="pihole_log"}'';
            stages = [{
              regex.expression = "^(?P<time>[A-Za-z]{3}[\ ]{1,2}[0-9]{1,2} [0-9:]{8}) (?P<content>.*)$";
            } {
              timestamp = {
                source = "time";
                format = "Jan 2 15:04:05";
                location = "Europe/Helsinki";
              };
            } {
              output.source = "content";
            }];
          };}];
        }];
        positions.filename = "/tmp/positions.yaml";
      }];
    };

    server = {
      log_level = "info";
    };
  };
*/
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "23.11";
}
