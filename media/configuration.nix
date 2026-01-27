{
  pkgs,
  inputs,
  ...
}:
let
  vars = import ./vars.nix { inherit pkgs; };

in
{
  # boot.kernelPackages = pkgs.linuxPackages_latest;

  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];

  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
      zfs = super.zfs.overrideAttrs (_: {
        meta.platforms = [ ];
      });
    })
  ];

  hardware.raspberry-pi."4".fkms-3d.enable = true;
  hardware.raspberry-pi."4".apply-overlays-dtmerge.enable = true;

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
    users.jellyfin = {
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
    gc = {
      automatic = true;
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
      serverAliases = [ "${vars.address}:80" ];
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.tailscale.enable = true;

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.05";
}
