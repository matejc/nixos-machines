{
  pkgs,
  inputs,
  lib,
  config,
  machineName,
  defaultUser,
  my,
  ...
}:
let
  music_video_subscriptions = pkgs.writeText "music_video_subscriptions.yaml" ''
    __preset__:
      overrides:
        music_video_directory: "/mnt/storage/music_videos"
      format: "(bv*[height<=1080]+bestaudio/best[height<=1080])"
      ytdl_options:
        merge_output_format: "mp4"

    "Jellyfin Music Videos":

      = Dance:
        "Dance": "${my.getSecretUnsafe "playlist-dance"}"

      = Metal:
        "Metal": "${my.getSecretUnsafe "playlist-metal"}"
  '';

  fetch_script = pkgs.writeShellScript "fetch_script" ''
    set -e
    export PATH="/run/current-system/sw/bin:$PATH"
    cd /mnt/storage/ytdl-sub
    ytdl-sub sub ${music_video_subscriptions}
  '';
  playlist_script = pkgs.writeShellScript "playlist_script" ''
    ${(import ./jellyfin { inherit pkgs; }).build}
  '';
in {
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
      id3v2
      yt-dlp
      ytdl-sub
    ];

  services.openssh.enable = true;
  services.openssh.extraConfig = ''
    AuthorizedKeysFile /run/agenix/authorizedkeys-%u
  '';

  users = {
    mutableUsers = false;
    users."${defaultUser}" = {
      isNormalUser = true;
      hashedPasswordFile = config.age.secrets.password.path;
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

  networking.nameservers = [ "86.54.11.100" "86.54.11.200" ];  # dns4eu
  networking.hostName = machineName;

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
      ExecStart = "${fetch_script}";
      Type = "oneshot";
      User = "jellyfin";
    };
  };
  systemd.timers."playlist_script" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Mon,Sat 01:00 UTC";
      Persistent = true;
      Unit = "playlist_script.service";
    };
  };
  systemd.services."playlist_script" = {
    serviceConfig = {
      EnvironmentFile = config.age.secrets.jellyfin-env.path;
      ExecStart = "${playlist_script}";
      Type = "oneshot";
      User = "jellyfin";
    };
  };

  # services.unifi = {
  #   enable = true;
  #   initialJavaHeapSize = 1024;
  #   maximumJavaHeapSize = 2048;
  #   openFirewall = true;
  #   mongodbPackage = pkgs.mongodb-ce;
  # };

  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;
    queryLogDeleter.enable = true;
    settings = {
      # See <https://docs.pi-hole.net/ftldns/configfile/>
      dns = {
        upstreams = config.networking.nameservers;
        hosts = [
          "${my.getSecretUnsafe "address"} media.home.arpa"
          "${my.getSecretUnsafe "address"} pihole.home.arpa"
          # "${my.getSecretUnsafe "address"} unifi.home.arpa"
          "${my.getSecretUnsafe "address"} ${config.networking.hostName}.${my.getSecretUnsafe "tailscale-domain"}"
        ];
        ignoreLocalhost = true;
      };
      webserver.api = {
        pwhash = my.getSecretUnsafe "pihole-pwhash";
        app_pwhash = my.getSecretUnsafe "pihole-app-pwhash";
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
    hostName = "pihole.home.arpa";
    ports = [ 18000 ];
  };

  services.piholeSchedule = {
    enable = true;
    apiUrl = "http://127.0.0.1:18000";
    environmentFile = config.age.secrets.pihole-env.path;
    timers = {
      kid-freetime = {
        start = "*-*-* 07:00:00";
        client_group_map = [
          { client = "26:8B:9D:7E:25:FB"; group = "Limited"; }  # phone
          { client = "64:D6:9A:BE:59:79"; group = "Limited"; }  # school laptop
        ];
      };
      kid-notime = {
        start = "*-*-* 21:30:00";
        client_group_map = [
          { client = "26:8B:9D:7E:25:FB"; group = "Block"; }  # phone
          { client = "64:D6:9A:BE:59:79"; group = "Block"; }  # school laptop
        ];
      };
    };
  };

  services.caddy = {
    enable = true;
    virtualHosts."media.home.arpa:443".extraConfig = ''
      reverse_proxy http://127.0.0.1:8096
      tls internal
    '';
    virtualHosts."media.home.arpa:80" = {
      extraConfig = ''
        reverse_proxy http://127.0.0.1:8096
      '';
    };
    # virtualHosts."unifi.home.arpa:443" = {
    #   extraConfig = ''
    #     reverse_proxy https://127.0.0.1:8443 {
    #       header_up Host {host}
    #       transport http {
    #         tls_insecure_skip_verify
    #       }
    #     }
    #   '';
    # };
    virtualHosts."pihole.home.arpa:443".extraConfig = ''
      reverse_proxy http://127.0.0.1:18000
      tls internal
    '';
    virtualHosts."${config.networking.hostName}.${my.getSecretUnsafe "tailscale-domain"}:443" = {
      extraConfig = ''
        tls internal
        reverse_proxy http://127.0.0.1:8096
      '';
    };
    virtualHosts."${config.networking.hostName}.${my.getSecretUnsafe "tailscale-domain"}:80" = {
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
        url = sys.env("LOKI_URL")
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
        url = sys.env("PROM_URL")
      }
    }
  '';
  services.alloy = {
    enable = true;
    environmentFile = config.age.secrets.alloy-env.path;
  };
}
