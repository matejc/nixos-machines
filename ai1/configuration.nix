{ config, pkgs, lib, ... }:
let
  vars = import ./vars.nix;
in {
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
    nano curl iproute2 htop tmux pciutils
    config.hardware.nvidia.package
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
  };
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "@wheel" ];

  hardware.enableRedistributableFirmware = true;

  networking.firewall = {
    allowedTCPPorts = [
      22
    ];
  };

  networking.nameservers = vars.nameservers;
  networking.hostName = vars.hostname;

  systemd.enableUnifiedCgroupHierarchy = false;

  services.tailscale.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = false;
    package = config.boot.kernelPackages.nvidiaPackages.dc_535;
    nvidiaPersistenced = true;
    datacenter.enable = true;
  };

  boot.initrd.kernelModules = [ "nvidia" ];
  boot.extraModulePackages = [ config.hardware.nvidia.package ];

  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
    autoPrune.enable = true;
    # enableNvidia = true;
    # daemon.settings  = {
    #   default-runtime = "nvidia";
      # exec-opts = ["native.cgroupdriver=cgroupfs"];
    #   runtimes.nvidia = let
    #     n = pkgs.runCommand "n" {
    #       nativeBuildInputs = [ pkgs.makeWrapper ];
    #     } ''
    #       mkdir -p $out/bin
    #       makeWrapper ${pkgs.nvidia-container-toolkit}/bin/nvidia-container-runtime $out/bin/nvidia-container-runtime \
    #         --prefix PATH : ${pkgs.libnvidia-container}/bin \
    #         --prefix LD_LIBRARY_PATH : ${config.hardware.nvidia.package}/lib
    #     '';
    #   in {
    #     path = "${n}/bin/nvidia-container-runtime";
    #     runtimeArgs = [];
    #   };
    # };
    # extraPackages = [ pkgs.libnvidia-container ];
  };
  # virtualisation.containers = {
  #   enable = true;
  #   cdi.dynamic.nvidia.enable = true;
  # };

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  services.ollama = {
    enable = true;
    acceleration = "cuda";
  };

  services.upaas = {
    enable = true;
    plugins = false;
    configuration = {
      stack = {
        llm = {
          enable = true;
          autostart = true;
          user = "llm";
          directory = "/var/lib/llm";
          compose = {
            version = "3";
            # services.vllm = {
            #   image = "vllm/vllm-openai:latest";
            #   ipc = "host";
            #   # runtime = "nvidia";
            #   environment = {
            #     HUGGING_FACE_HUB_TOKEN = vars.huggingface_token;
            #     NVIDIA_VISIBLE_DEVICES = "all";
            #   };
            #   volumes = [
            #     "/var/lib/llm/huggingface:/root/.cache/huggingface"
            #   ];
            #   ports = [ "8000:8000" ];
            #   command = [ "--model=google/gemma-7b" "--dtype=half" ];
            #   deploy.resources.reservations.devices = [{
            #     driver = "nvidia";
            #     count = "all";
            #     capabilities = ["gpu"];
            #   }];
            # };
            services.openwebui = {
              image = "ghcr.io/open-webui/open-webui:main";
              environment = {
                OLLAMA_BASE_URL = "http://127.0.0.1:11434";
              };
              volumes = [
                "/var/lib/llm/open-webui:/app/backend/data"
              ];
              # links = [ "vllm" ];
              # ports = [ "3000:8080" ];
              network_mode = "host";
            };
          };
        };
      };
    };
  };

  users.users.llm = {
    isNormalUser = true;
    createHome = true;
    home = "/var/lib/llm";
    extraGroups = [ "docker" ];
  };
  users.groups.llm = {};

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;

  system.stateVersion = "23.11";
}
