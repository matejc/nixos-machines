# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, lib, my, machineName, ... }:
let
  ip = my.getSecretUnsafe "ip";
  ipv6 = my.getSecretUnsafe "ipv6";
  macaddress = my.getSecretUnsafe "macaddress";
  gateway = my.getSecretUnsafe "gateway";
  gatewayv6 = my.getSecretUnsafe "gatewayv6";
  nameserver1 = my.getSecretUnsafe "nameserver1";
  nameserver2 = my.getSecretUnsafe "nameserver2";
  netbirdIp = my.getSecretUnsafe "netbird-ip";

  user = my.getSecretUnsafe "user";
  email = my.getSecretUnsafe "email";

  matej70Pub = my.getSecretUnsafe "matej70-pub";
  matej80Pub = my.getSecretUnsafe "matej80-pub";
  builderPub = my.getSecretUnsafe "builder-pub";

  opensshPort = my.getSecretUnsafe "ssh-port";

  anythingLlmEnvFile = config.age.secrets.anything-llm-env.path;

  borgbackupRepo = my.getSecretUnsafe "borgbackup-repo";
  borgbackupPassFile = config.age.secrets.borgbackup-pass.path;
  borgbackupKeyFile = config.age.secrets.borgbackup-key.path;

  hydraDomain = my.getSecretUnsafe "hydra-domain";
  cacheDomain = my.getSecretUnsafe "cache-domain";
  searxDomain = my.getSecretUnsafe "searx-domain";
  matrixDomain = my.getSecretUnsafe "matrix-domain";
  myipDomain = my.getSecretUnsafe "myip-domain";
  jitsiDomain = my.getSecretUnsafe "jitsi-domain";

  harmoniaSecretFile = config.age.secrets.harmonia-secret.path;
  searxBasicAuthFile = config.age.secrets.searx-basic-auth.path;

  alloyEnvFile = config.age.secrets.alloy-env.path;
  builderKeyFile = config.age.secrets.builder-key.path;

  matrixRegTokenFile = config.age.secrets.matrix-reg-token.path;

  whatsappBridgeConf = my.importNixFromSecretUnsafe "whatsapp-bridge.nix" { inherit pkgs user matrixDomain; };
  telegramBridgeConf = my.importNixFromSecretUnsafe "telegram-bridge.nix" { inherit pkgs user matrixDomain; };
  metaBridgeConf = my.importNixFromSecretUnsafe "meta-bridge.nix" { inherit pkgs user matrixDomain; };
  discordBridgeConf = my.importNixFromSecretUnsafe "discord-bridge.nix" { inherit pkgs user matrixDomain; };
  signalBridgeConf = my.importNixFromSecretUnsafe "signal-bridge.nix" { inherit pkgs user matrixDomain; };
  slackBridgeConf = my.importNixFromSecretUnsafe "slack-bridge.nix" { inherit pkgs user matrixDomain; };

  searxEnvFile = config.age.secrets.searx-env.path;
  skyrimIniFile = config.age.secrets.skyrim-ini.path;
in
{
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking.hostName = machineName;

  networking.useDHCP = false;
  # modules.hetzner.wan = {
  #   enable = true;
  #   macAddress = "...";
  #   ipAddresses = [
  #     "${ip}/32"
  #     "${ipv6}/64"
  #   ];
  # };
  systemd.network = {
    enable = true;
    networks."10-internet" = {
      matchConfig.MACAddress = macaddress;
      linkConfig.RequiredForOnline = "routable";
      address = [
        "${ip}/32"
        "${ipv6}/64"
      ];
      routes = [
        {
          Gateway = gateway;
          GatewayOnLink = true;
        }
        {
          Gateway = gatewayv6;
          GatewayOnLink = true;
        }
      ];
      dns = [
        nameserver1
        nameserver2
      ];
    };
  };
  systemd.network.wait-online.anyInterface = true;

  services.resolved.enable = false;
  networking.nameservers = [
    nameserver1
    nameserver2
  ];

  i18n = {
    defaultLocale = "en_US.UTF-8";
  };
  console = {
    keyMap = "us";
    font = "Lat2-Terminus16";
  };

  environment.systemPackages = with pkgs; [
    curl
    nano
    wget
    vim
    git
    tmux
    htop
    btop

    aspell
    aspellDicts.en

    iftop
    nethogs

    openssl
    bind
    ncdu

    (pkgs.writeScriptBin "mount.fuse.borgfs" ''
      #!${pkgs.stdenv.shell}
      export BORG_RSH="ssh -i /home/${user}/.ssh/id_ed25519"
      export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes
      export BORG_RELOCATED_REPO_ACCESS_IS_OK=yes
      exec ${pkgs.borgbackup}/bin/borgfs "$@"
    '')
  ];

  programs.nixmy = {
    enable = true;
    backupRemote = "git@github.com:matejc/configurations.git";
    nixpkgsRemote = "https://github.com/matejc/nixpkgs";
    nixpkgsLocalPath = "${inputs.nixpkgs}";
  };

  services.openssh = {
    enable = true;
    ports = [ (lib.toInt opensshPort) ];
    settings.PermitRootLogin = "no";
  };

  programs.mosh.enable = true;
  services.fail2ban = {
    enable = true;
    bantime-increment.enable = true;
    maxretry = 5;
    jails = {
      refused-connections.settings = {
        enabled = true;
        findtime = 600;
        bantime = 300;
        maxretry = 5;
      };
    };
  };
  systemd.services.fail2ban.serviceConfig.StateDirectoryMode = pkgs.lib.mkForce "0755";
  environment.etc."fail2ban/filter.d/refused-connections.conf".text = ''
    [Definition]
    backend = systemd
    mode = normal
    action = ${config.services.fail2ban.banaction-allports}[name=refusedconn, protocol=all, blocktype=DROP]
    journalmatch = _TRANSPORT=kernel
    failregex = ^.*refused connection: IN=[0-9a-z]+ OUT=[^\ ]* MAC=[a-f0-9\:]* SRC=<HOST> .*$
    ignoreregex =
  '';

  security.acme = {
    defaults.email = email;
    acceptTerms = true;
  };

  services.caddy.enable = true;
  # services.caddy.acmeCA = "https://acme-staging-v02.api.letsencrypt.org/directory";

  age.secrets.searx-basic-auth.owner = "caddy";

  services.caddy.virtualHosts.${myipDomain}.extraConfig = ''
    header Content-Type text/plain
    templates
    respond "{{.RemoteIP}}"
  '';

  programs.screen = {
    enable = true;
    screenrc = ''
      defscrollback 10000
      startup_message off
    '';
  };

  services.caddy.virtualHosts.${hydraDomain}.extraConfig = ''
    reverse_proxy http://127.0.0.1:54444
  '';

  services.caddy.virtualHosts.${cacheDomain}.extraConfig = ''
    encode
    reverse_proxy http://127.0.0.1:53333
  '';

  services.harmonia.cache = {
    enable = true;
    signKeyPaths = [ harmoniaSecretFile ];
    settings = {
      bind = "127.0.0.1:53333";
    };
  };

  services.caddy.virtualHosts.${searxDomain}.extraConfig = ''
    handle_path /static/* {
        root * ${config.services.searx.package}/share/static
        file_server
    }
    handle {
        basic_auth {
            import ${searxBasicAuthFile}
        }
        reverse_proxy http://${config.services.searx.uwsgiConfig.http}
    }
  '';
  services.searx = {
    enable = true;
    environmentFile = searxEnvFile;
    settings = {
      outgoing.proxies."all://" = [ "socks5://${netbirdIp}:1080" ];
      server = {
        secret_key = "$SEARX_SECRET_KEY";
      };
      ui.static_use_hash = true;
      search.formats = [ "html" "json" ];
    };
    configureUwsgi = true;
    uwsgiConfig = {
      disable-logging = true;
      http = "127.0.0.1:53418";
    };
  };

  services.coturn = {
    enable = true;
    static-auth-secret-file = config.age.secrets.coturn-secret.path;
    use-auth-secret = true;
    realm = matrixDomain;
    min-port = 49152;
    max-port = 59152;
    listening-port = 3478;
    extraConfig = ''
      user-quota=12
      total-quota=1200
      external-ip=${ip}

      listening-ip=${ip}
      relay-ip=${ip}
      server-name=${matrixDomain}
      lt-cred-mech
      no-loopback-peers
      no-multicast-peers
    '';
  };
  age.secrets.coturn-secret.owner = "turnserver";

  age.secrets.skyrim-ini.owner = "skyrim";
  age.secrets.corekeeper-env.owner = "corekeeper";
  age.secrets.icarus-env.owner = "icarus";
  age.secrets.swords-env.owner = "swords";
  age.secrets.windrose-env.owner = "windrose";
  services.upaas = {
    enable = true;
    user = user;
    plugins = false;
    configuration = {
      stack = {
        skyrim = {
          enable = false;
          autostart = true;
          user = "skyrim";
          group = "skyrim";
          directory = "/var/lib/skyrim";
          compose = {
            version = "3";
            services.skyrim = {
              image = "tiltedphoques/st-reborn-server:latest";
              ports = [
                "${ip}:10578:10578/udp"
              ];
              volumes =
                [
                  "${skyrimIniFile}:/st-server/config/STServer.ini:ro"
                  "/var/lib/skyrim/config:/st-server/config"
                  "/var/lib/skyrim/logs:/st-server/logs"
                  "/var/lib/skyrim/Data:/st-server/Data"
                  "/etc/localtime:/etc/localtime:ro"
                  "/etc/timezone:/etc/timezone:ro"
                ];
              stdin_open = true;
              tty = true;
            };
          };
        };

        satisfactory = {
          enable = false;
          autostart = true;
          user = "satisfactory";
          group = "satisfactory";
          directory = "/var/lib/satisfactory";
          compose = {
            services.satisfactory = {
              image = "wolveix/satisfactory-server:latest";

              ports = [
                "${ip}:7777:7777/udp"
                "${ip}:7777:7777/tcp"
                "${ip}:8888:8888/tcp"
              ];

              environment = {
                MAXPLAYERS = "5";
                PGID = "${toString config.users.groups.satisfactory.gid}";
                PUID = "${toString config.users.users.satisfactory.uid}";
                STEAMBETA = "false";
                ROOTLESS = "false";
                AUTOPAUSE = "true";
              };
              volumes = [
                "/var/lib/satisfactory/config:/config"
              ];
              deploy.resources = {
                limits.memory = "16G";
                reservations.memory = "16G";
              };
            };
          };
        };

        corekeeper = {
          enable = false;
          autostart = true;
          user = "corekeeper";
          group = "corekeeper";
          directory = "/var/lib/corekeeper";
          compose = {
            services.corekeeper = {
              image = "escaping/core-keeper-dedicated:latest";
              env_file = config.age.secrets.corekeeper-env.path;
              volumes = [
                "/var/lib/corekeeper/dedicated:/home/steam/core-keeper-dedicated"
                "/var/lib/corekeeper/data:/home/steam/core-keeper-data"
              ];
            };
          };
        };

        enshrouded = {
          enable = false;
          autostart = true;
          user = "enshrouded";
          group = "enshrouded";
          directory = "/var/lib/enshrouded";
          compose = {
            services.enshrouded = {
              image = "sknnr/enshrouded-dedicated-server:latest";
              ports = [
                "${ip}:15636:15636/udp"
                "${ip}:15637:15637/udp"
                "${ip}:15636:15636/tcp"
                "${ip}:15637:15637/tcp"
              ];
              environment = {
                SERVER_NAME = "Lunden";
                SERVER_PASSWORD = "ovce!";
                GAME_PORT = "15636";
                QUERY_PORT = "15637";
                SERVER_SLOTS = "10";
                SERVER_IP = "0.0.0.0";
              };
              volumes = [
                "/var/lib/enshrouded/savegame:/home/steam/enshrouded/savegame"
              ];
            };
          };
        };

        icarus = {
          enable = false;
          autostart = true;
          user = "icarus";
          group = "icarus";
          directory = "/var/lib/icarus";
          compose = {
            services.icarus = {
              image = "mornedhels/icarus-server:latest";
              stop_grace_period = "90s";
              ports = [
                "${ip}:17777:17777/udp"
                "${ip}:27015:27015/udp"
                "${ip}:17777:17777/tcp"
                "${ip}:27015:27015/tcp"
              ];
              env_file = config.age.secrets.icarus-env.path;
              volumes = [
                "/var/lib/icarus/data:/home/icarus/drive_c/icarus"
                "/var/lib/icarus/game:/opt/icarus"
              ];
            };
          };
        };

        avorion = {
          enable = false;
          autostart = true;
          user = "avorion";
          group = "avorion";
          directory = "/var/lib/avorion";
          compose = {
            services.avorion = {
              image = "rfvgyhn/avorion:stable";
              ports = [
                "${ip}:27000:27000"
                "${ip}:27000:27000/udp"
                "${ip}:27003:27003/udp"
                "${ip}:27020:27020/udp"
                "${ip}:27021:27021/udp"
              ];
              stdin_open = true;
              tty = true;
              volumes = [
                "/var/lib/avorion/avorion_galaxy:/home/steam/.avorion/galaxies/avorion_galaxy"
                "/var/lib/avorion/backups:/home/steam/.avorion/backups"
              ];
            };
          };
        };

        llm = {
          enable = true;
          autostart = true;
          user = "llm";
          group = "llm";
          directory = "/var/lib/llm";
          compose = {
            services.anything-llm = {
              image = "mintplexlabs/anythingllm:latest";
              volumes = [
                "/var/lib/llm/server/.env:/app/server/.env"
                "/var/lib/llm/server/storage:/app/server/storage"
                "/var/lib/llm/collector/hotdir:/app/collector/hotdir"
                "/var/lib/llm/collector/outputs:/app/collector/outputs"
              ];
              env_file = [ "/var/lib/llm/server/.env" ];
              ports = [ "${netbirdIp}:3001:3001" ];
              network_mode = "bridge";
              cap_add = [ "SYS_ADMIN" ]; # for wep page scraping (chromium sandboxing)
            };
          };
        };

        swords = {
          enable = false;
          autostart = true;
          user = "swords";
          group = "swords";
          directory = "/var/lib/UnraidGameServers";
          compose = {
            services.swords = {
              build = {
                context = "/var/lib/UnraidGameServers";
                dockerfile = "/var/lib/UnraidGameServers/Dockerfile";
              };
              ports = [
                "${ip}:7777:7777/udp"
                "${ip}:27015:27015/udp"
              ];
              env_file = config.age.secrets.swords-env.path;
              volumes = [
                "/var/lib/swords/steamcmd:/serverdata/steamcmd"
                "/var/lib/swords/serverfiles:/serverdata/serverfiles"
              ];
            };
          };
        };

        warp = {
          enable = true;
          autostart = true;
          user = "warp";
          directory = "/var/lib/warp-docker";
          deps = [ pkgs.git ];
          compose = {
            services.warp = {
              image = "caomingjun/warp:latest";
              device_cgroup_rules = [ "c 10:200 rwm" ];
              environment = {
                WARP_SLEEP = "2";
              };
              cap_add = [ "NET_ADMIN" ];
              sysctls = [
                "net.ipv6.conf.all.disable_ipv6=0"
                "net.ipv4.conf.all.src_valid_mark=1"
                "net.ipv4.ip_forward=1"
              ];
              ports = [
                "${netbirdIp}:1080:1080"
              ];
              volumes = [
                "/var/lib/warp:/var/lib/cloudflare-warp"
              ];
            };
          };
        };

        moria = {
          enable = false;
          autostart = true;
          user = "moria";
          group = "moria";
          directory = "/var/lib/moria";
          compose = {
            services.moria = {
              image = "andrewsav/moria:latest";
              stop_signal = "SIGINT";
              volumes = [ "/var/lib/moria/server:/server" ];
              ports = [ "${ip}:7777:7777/udp" ];
              stdin_open = true;
              tty = true;
            };
          };
        };

        starr = {
          enable = false;
          autostart = true;
          user = "starr";
          group = "starr";
          directory = "/var/lib/starr";
          compose = {
            services.starr = {
              image = "struppinet/starrupture-dedicated-server:latest";
              volumes = [
                "/var/lib/starr/savegames:/home/container/server_files/StarRupture/Saved/SaveGames"
                "/var/lib/starr/server:/home/container/server_files"
              ];
              ports = [
                "${ip}:7777:7777/udp"
              ];
              environment = {
                SERVER_PORT = "7777";
                USE_DSSETTINGS = "true";
              };
            };
          };
        };

        matrix-steam-bridge = {
          enable = true;
          autostart = true;
          user = "sbridge";
          group = "sbridge";
          directory = "/var/lib/sbridge";
          compose = {
            services.sbridge = {
              image = "ghcr.io/jasonlaguidice/matrix-steam-bridge:latest";
              volumes = [
                "/var/lib/sbridge/config:/app/config:rw"
                "/var/lib/sbridge/config.yaml:/app/config/config.yaml:ro"
                "/var/lib/sbridge/registration.yaml:/app/config/registration.yaml:ro"
                "/var/lib/sbridge/data:/app/data"
                "/var/lib/sbridge/logs:/app/logs"
              ];
              ports = [
                "127.0.0.1:29189:8080"
              ];
            };
          };
        };

        windrose = {
          enable = false;
          autostart = true;
          user = "windrose";
          group = "windrose";
          directory = "/var/lib/windrose";
          compose = {
            services.windrose = {
              image = "indifferentbroccoli/windrose-server-docker:latest";
              volumes = [
                "/var/lib/windrose/server-files:/home/steam/server-files"
              ];
              ports = [
                "${netbirdIp}:8780:8780/tcp"
              ];
              stop_grace_period = "30s";
              env_file = config.age.secrets.windrose-env.path;
            };
          };
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
    8448
    config.services.coturn.listening-port
    (lib.toInt opensshPort)
  ];
  networking.firewall.allowedUDPPorts = [
    config.services.tailscale.port
    config.services.coturn.listening-port
  ];
  networking.firewall.allowedUDPPortRanges = [
    {
      from = config.services.coturn.min-port;
      to = config.services.coturn.max-port;
    }
  ];
  networking.firewall.trustedInterfaces = [ "docker0" ];

  users.users.root = {
    initialHashedPassword = "";
    openssh.authorizedKeys.keys = [
      matej70Pub
      matej80Pub
    ];
  };

  users.users.${user} = {
    isNormalUser = true;
    group = user;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      matej70Pub
      matej80Pub
    ];
  };
  users.groups.${user} = { };
  security.sudo.wheelNeedsPassword = false;

  nix.settings.trusted-users = [
    "@wheel"
    "builder"
  ];

  users.users.builder = {
    isNormalUser = true;
    group = "builder";
    openssh.authorizedKeys.keys = [ builderPub ];
  };
  users.groups.builder = { };

  users.users.corekeeper = {
    isNormalUser = true;
    createHome = true;
    home = "/var/lib/corekeeper";
    extraGroups = [ "docker" ];
  };
  users.groups.corekeeper = { };

  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
    autoPrune = {
      flags = [ "--all" ];
      enable = true;
    };
  };

  users.users.satisfactory = {
    isNormalUser = true;
    createHome = true;
    group = "satisfactory";
    home = "/var/lib/satisfactory";
    extraGroups = [ "docker" ];
  };
  users.groups.satisfactory = { };

  users.users.skyrim = {
    isNormalUser = true;
    createHome = true;
    group = "skyrim";
    home = "/var/lib/skyrim";
    extraGroups = [ "docker" ];
  };
  users.groups.skyrim = { };

  users.users.enshrouded = {
    isNormalUser = true;
    createHome = true;
    group = "enshrouded";
    home = "/var/lib/enshrouded";
    extraGroups = [ "docker" ];
  };
  users.groups.enshrouded = { };

  users.users.icarus = {
    isNormalUser = true;
    createHome = true;
    group = "icarus";
    home = "/var/lib/icarus";
    extraGroups = [ "docker" ];
  };
  users.groups.icarus = { };

  users.users.avorion = {
    isNormalUser = true;
    createHome = true;
    group = "avorion";
    home = "/var/lib/avorion";
    extraGroups = [ "docker" ];
  };
  users.groups.avorion = { };

  users.users.llm = {
    isNormalUser = true;
    createHome = true;
    group = "llm";
    home = "/var/lib/llm";
    extraGroups = [ "docker" ];
    uid = 1006;
  };
  users.groups.llm.gid = 975;

  users.users.swords = {
    isNormalUser = true;
    createHome = true;
    group = "swords";
    home = "/var/lib/swords";
    extraGroups = [ "docker" ];
  };
  users.groups.swords = { };

  users.users.warp = {
    isNormalUser = true;
    createHome = true;
    group = "warp";
    home = "/var/lib/warp";
    extraGroups = [ "docker" ];
  };
  users.groups.warp = { };

  users.users.moria = {
    isNormalUser = true;
    createHome = true;
    group = "moria";
    home = "/var/lib/moria";
    extraGroups = [ "docker" ];
  };
  users.groups.moria = { };

  users.users.starr = {
    isNormalUser = true;
    createHome = true;
    group = "starr";
    home = "/var/lib/starr";
    extraGroups = [ "docker" ];
  };
  users.groups.starr = { };

  users.users.windrose = {
    isNormalUser = true;
    createHome = true;
    group = "windrose";
    home = "/var/lib/windrose";
    extraGroups = [ "docker" ];
  };
  users.groups.windrose = { };

  users.users.sbridge = {
    isNormalUser = true;
    createHome = true;
    group = "sbridge";
    home = "/var/lib/sbridge";
    extraGroups = [ "docker" ];
  };
  users.groups.sbridge = { };

  services.jitsi-meet = {
    enable = true;
    hostName = jitsiDomain;
    caddy.enable = true;
    nginx.enable = false;
    secureDomain.enable = true;
    prosody.lockdown = true;
    config = {
      welcomePage.disabled = true;
      prejoinConfig.enabled = false;
      lobby.enableChat = false;
      defaultLanguage = "en";
    };
    interfaceConfig = {
      SHOW_JITSI_WATERMARK = false;
      SHOW_WATERMARK_FOR_GUESTS = false;
    };
  };

  services.syncthing = {
    enable = true;
    dataDir = "/var/syncthing/";
    configDir = "/var/syncthing/config";
    openDefaultPorts = true;
  };

  services.borgbackup.jobs = {
    backup = {
      paths = [
        "/var/lib"
        "/var/syncthing"
      ];
      exclude = [
        "/var/lib/docker"
        "/var/lib/ollama-home"
        "/var/lib/private/alloy"
        "*.log"
        "/var/lib/hydra"
        "/var/lib/postgresql"
      ];
      doInit = false;
      repo = borgbackupRepo;
      encryption = {
        mode = "repokey-blake2";
        passCommand = "cat ${borgbackupPassFile}";
      };
      environment = {
        BORG_RSH = "ssh -i ${borgbackupKeyFile}";
      };
      compression = "auto,lzma";
      startAt = "daily";
      prune.keep = {
        within = "1d"; # Keep all archives from the last day
        daily = 7;
        weekly = 4;
        monthly = -1;  # Keep at least one archive for each month
      };
    };
  };

  environment.etc."alloy/loki.alloy".text = ''
    loki.relabel "journal" {
      forward_to = []

      rule {
        source_labels = [ "__journal__systemd_unit" ]
        target_label = "unit"
      }
      rule {
        source_labels = [ "__journal__boot_id" ]
        target_label = "boot_id"
      }
      rule {
        source_labels = [ "__journal__transport" ]
        target_label = "transport"
      }
      rule {
        source_labels = [ "__journal_priority_keyword" ]
        target_label = "level"
      }
    }

    loki.source.journal "read"  {
      forward_to    = [loki.write.endpoint.receiver]
      relabel_rules = loki.relabel.journal.rules
      labels        = {
        component = "loki.source.journal",
        instance = "${config.networking.hostName}",
      }
    }

    loki.write "endpoint" {
      endpoint {
        url = env("LOKI_URL")
      }
    }
  '';
  environment.etc."alloy/prometheus.alloy".text = ''
    prometheus.exporter.unix "local_system" {
      enable_collectors = ["systemd"]
    }

    prometheus.scrape "local_system" {
      targets         = prometheus.exporter.unix.local_system.targets
      forward_to      = [prometheus.remote_write.metrics_service.receiver]
    }

    prometheus.scrape "endlessh" {
      targets         = [
        { "__address__" = "localhost:2112" },
      ]
      forward_to      = [prometheus.remote_write.metrics_service.receiver]
    }

    prometheus.remote_write "metrics_service" {
      endpoint {
        url = env("PROM_URL")
      }
    }
  '';

  services.alloy = {
    enable = true;
    environmentFile = alloyEnvFile;
  };

  services.netbird = {
    enable = true;
    useRoutingFeatures = "both";
  };

  services.earlyoom.enable = true;
  services.earlyoom.freeMemThreshold = 5;

  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep 10 --keep-since 14d";
      dates = "weekly";
    };
  };

  # nix.settings.cores = 12;
  # nix.settings.max-jobs = 2;
  nix.settings.extra-experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.allowed-uris = [
    "github:"
    "git+https:"
    "git+ssh://github.com/"
    "https://github.com/"
    "https://api.github.com/"
    "https://channels.nixos.org/"
    "https://gitlab.com/"
    "https://api.flakehub.com/"
    "https://releases.nixos.org/"
  ];
  nix.buildMachines = [
    {
      hostName = "local-builder";
      maxJobs = 2;
      sshKey = builderKeyFile;
      sshUser = "builder";
      supportedFeatures = [
        "benchmark"
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
      systems = [
        "i686-linux"
        "x86_64-linux"
        "aarch64-linux"
      ];
    }
  ];
  programs.ssh.extraConfig = ''
    Host local-builder
      User builder
      HostName 127.0.0.1
      Port ${opensshPort}
      IdentityFile ${builderKeyFile}
  '';
  age.secrets.builder-key.group = "hydra";
  age.secrets.builder-key.mode = "550";

  services.hydra = {
    enable = true;
    package = pkgs.hydra.overrideAttrs (old: {
      doCheck = false;
    });
    port = 54444;
    listenHost = "127.0.0.1";
    hydraURL = "https://${hydraDomain}";
    notificationSender = "hydra@localhost";
    # a standalone hydra will require you to unset the buildMachinesFiles list to avoid using a nonexistant /etc/nix/machines
    # buildMachinesFiles = [];
    # you will probably also want, otherwise *everything* will be built from scratch
    useSubstitutes = true;
  };
  systemd.tmpfiles.rules = [
    "d /var/cache/hydra                0755 hydra-queue-runner hydra -  -"
  ];

  services.matrix-continuwuity = {
    enable = true;
    settings = {
      global = {
        address = [ "127.0.0.1" ];
        port = [ 6167 ];
        server_name = matrixDomain;
        database_backend = "rocksdb";
        allow_registration = false;
        allow_federation = true;
        allow_encryption = true;
        registration_token_file = matrixRegTokenFile;
        new_user_displayname_suffix = "";
        max_request_size = 20000000;
        turn_uris = [
          "turn:${matrixDomain}?transport=udp"
          "turn:${matrixDomain}?transport=tcp"
        ];
        turn_secret_file = config.age.secrets.turn-secret.path;
        # force_migration = true;
      };
    };
  };
  age.secrets.matrix-reg-token.owner = "continuwuity";
  age.secrets.turn-secret = my.cloneSecret "coturn-secret" { owner = "continuwuity"; };

  services.matrix-appservices = {
    services = {
      whatsapp = whatsappBridgeConf;
      telegram = telegramBridgeConf;
      meta = metaBridgeConf;
      discord = discordBridgeConf;
      signal = signalBridgeConf;
      slack = slackBridgeConf;
    };
    homeserver = null;
    homeserverDomain = matrixDomain;
  };

  systemd.services.matrix-as-signal.path = [ pkgs.ffmpeg ];
  systemd.services.matrix-as-telegram.path = [ pkgs.ffmpeg ];
  systemd.services.matrix-as-meta.path = [ pkgs.ffmpeg ];
  systemd.services.matrix-as-whatsapp.path = [ pkgs.ffmpeg ];
  systemd.services.matrix-as-discord.path = [ pkgs.ffmpeg ];
  systemd.services.matrix-as-slack.path = [ pkgs.ffmpeg ];

  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
    "conduwuit-0.4.6"
    "jitsi-meet-1.0.9365"
  ];

  services.caddy.virtualHosts.${matrixDomain} = {
    serverAliases = [ "${matrixDomain}:8448" ];
    extraConfig = ''
      reverse_proxy 127.0.0.1:6167
    '';
  };

  users.users.turnserver.extraGroups = [ "acme" ];

  services.postgresql.package = pkgs.postgresql_17;

  system.activationScripts.llm.text = ''
    mkdir -p /var/lib/llm/server/storage
    mkdir -p /var/lib/llm/collector/hotdir
    mkdir -p /var/lib/llm/collector/outputs
    if [ ! -f /var/lib/llm/server/.env ]
    then
      cat ${anythingLlmEnvFile} > /var/lib/llm/server/.env
    fi
    if [ ! -f /var/lib/llm/server/storage/anythingllm.db ]
    then
      ${pkgs.sqlite}/bin/sqlite3 /var/lib/llm/server/storage/anythingllm.db "VACUUM;"
    fi
    chown -R 1000:1000 /var/lib/llm/{server,collector}
  '';

  services.endlessh-go = {
    enable = true;
    port = 22;
    openFirewall = true;
    extraOptions = [
      "-geoip_supplier=max-mind-db"
      "-max_mind_db=/var/lib/GeoLite2-Country.mmdb"
    ];
    prometheus = {
      enable = true;
      port = 2112;
      listenAddress = "127.0.0.1";
    };
  };
  systemd.services.endlessh-go.serviceConfig.BindReadOnlyPaths = [ "/var/lib/GeoLite2-Country.mmdb" ];

  programs.proxychains = {
    enable = true;
    package = pkgs.proxychains-ng;
    proxies = {
      warp = {
        enable = true;
        type = "socks5";
        host = netbirdIp;
        port = 1080;
      };
    };
    quietMode = true;
  };

  services.homebox = {
    enable = true;
    settings = {
      HBOX_WEB_HOST = "127.0.0.1";
      HBOX_WEB_PORT = "7745";
      HBOX_OPTIONS_ALLOW_REGISTRATION = "false";
      HBOX_OPTIONS_ALLOW_ANALYTICS = "false";
    };
  };
  services.cloudflared = {
    enable = true;
    tunnels.${my.getSecretUnsafe "homebox-tunnel"} = {
      credentialsFile = config.age.secrets.cloudflared-homebox.path;
      ingress = {
        ${my.getSecretUnsafe "homebox-domain"} = "http://127.0.0.1:7745";
      };
      default = "http_status:404";
    };
  };

  time.timeZone = "Europe/Helsinki";

  services.qemuGuest.enable = true;

  system.stateVersion = "23.11";
}
