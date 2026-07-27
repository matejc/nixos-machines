{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
let
  vars = import ./vars.nix { inherit pkgs; };
in
lib.recursiveUpdate {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  time.timeZone = "Europe/Helsinki";

  environment.systemPackages =
    with pkgs;
    [
      nano
      curl
      iproute2
      htop
      ncdu
      tmux
      jq
    ]
    ++ vars.packages;

  services.openssh.enable = true;

  users = {
    mutableUsers = false;
    users."${vars.user}" = {
      isNormalUser = true;
      password = vars.password;
      openssh.authorizedKeys.keys = vars.authorizedKeys;
      extraGroups = [ "wheel" ];
    };
    users.jellyfin = lib.mkIf config.services.jellyfin.enable {
      home = "/mnt/storage/jellyfin-home";
      createHome = true;
      extraGroups = [ "video" ];
    };
  };
  security.sudo.wheelNeedsPassword = false;

  nix = {
    channel.enable = false;
    settings = {
      nix-path = "nixpkgs=${inputs.nixpkgs}";
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ "@wheel" ];
    };
  };

  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep 10 --keep-since 7d";
      dates = "daily";
    };
  };

  hardware.enableRedistributableFirmware = true;

  networking.nameservers = vars.nameservers;
  networking.hostName = vars.hostname;

  services.jellyfin = {
    enable = true;
    dataDir = "/mnt/storage/jellyfin-data";
    cacheDir = "/mnt/storage/jellyfin-cache";
    hardwareAcceleration = {
      enable = true;
      type = "vaapi";
      device = "/dev/dri/renderD128";
    };
  };

  systemd.timers."fetch_script" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Mon,Sat 00:00 UTC";
      Persistent = true;
      Unit = "fetch_script.service";
    };
  };
  systemd.services."fetch_script" = {
    serviceConfig = {
      ExecStart = "/run/current-system/sw/bin/fetch_script";
      Type = "oneshot";
      User = "jellyfin";
    };
  };

  services.unifi = {
    enable = true;
    initialJavaHeapSize = 1024;
    maximumJavaHeapSize = 2048;
    openFirewall = true;
    mongodbPackage = pkgs.mongodb-ce;
  };

  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;
    queryLogDeleter.enable = true;
    settings = {
      # See <https://docs.pi-hole.net/ftldns/configfile/>
      dns = {
        upstreams = vars.nameservers;
        hosts = [
          "${vars.address} media.local"
          "${vars.address} pihole.local"
          "${vars.address} unifi.local"
          "${vars.address} ${vars.hostname}.${vars.domain}"
        ];
        ignoreLocalhost = true;
      };
      webserver.api = {
        pwhash = vars.pihole_pwhash;
        app_pwhash = vars.pihole_app_pwhash;
      };
    };
    lists = [
      { url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"; description = "adware + malware"; type = "block"; }
      { url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-only/hosts"; description = "fakenews"; type = "block"; }
      { url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling-only/hosts"; description = "gambling"; type = "block"; }
      { url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts"; description = "porn"; type = "block"; }
      { url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/social-only/hosts"; description = "social"; type = "block"; }
      { url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/anti.piracy.txt"; description = "antipiracy"; type = "block"; }
      { url = "https://raw.githubusercontent.com/oneoffdallas/dohservers/master/list.txt"; description = "doh"; type = "block"; }
      { url = "https://raw.githubusercontent.com/matejc/AdGuard_GameList-Filter/main/PiHole_games_list.txt"; description = "games"; type = "block"; }
    ];
  };

  services.pihole-web = {
    enable = true;
    hostName = "pihole.local";
    ports = [ 18000 ];
  };

  services.caddy = {
    enable = true;
    virtualHosts."media.local:443".extraConfig = ''
      reverse_proxy http://127.0.0.1:8096
      tls internal
    '';
    virtualHosts."media.local:80" = {
      extraConfig = ''
        reverse_proxy http://127.0.0.1:8096
      '';
    };
    virtualHosts."unifi.local:443" = {
      extraConfig = ''
        reverse_proxy https://127.0.0.1:8443 {
          header_up Host {host}
          transport http {
            tls_insecure_skip_verify
          }
        }
      '';
    };
    virtualHosts."pihole.local:443".extraConfig = ''
      reverse_proxy http://127.0.0.1:18000
      tls internal
    '';
    virtualHosts."${vars.hostname}.${vars.domain}:443" = {
      extraConfig = ''
        tls internal
        reverse_proxy http://127.0.0.1:8096
      '';
    };
    virtualHosts."${vars.hostname}.${vars.domain}:80" = {
      extraConfig = ''
        reverse_proxy http://127.0.0.1:8096
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.tailscale.enable = true;

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";

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
        url = "${vars.loki_push_url}"
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

    prometheus.remote_write "metrics_service" {
      endpoint {
        url = "${vars.prom_push_url}"
      }
    }
  '';
  services.alloy = {
    enable = true;
  };

} vars.config
