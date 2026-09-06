{ config, pkgs, my, defaultUser, machineName, ... }:
let
  kid = my.getSecret "kid";
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot = {
    kernelParams = [
      "mem_sleep_default=s2idle"
    ];
  };

  services.scx.enable = true;
  services.scx.scheduler = "scx_bpfland";
  services.scx.extraArgs = [
    "-m"
    "performance"
  ];
  services.scx.package = pkgs.scx.full;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = machineName;
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";
  services.resolved.enable = true;

  time.timeZone = "Europe/Helsinki";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fi_FI.UTF-8";
    LC_IDENTIFICATION = "fi_FI.UTF-8";
    LC_MEASUREMENT = "fi_FI.UTF-8";
    LC_MONETARY = "fi_FI.UTF-8";
    LC_NAME = "fi_FI.UTF-8";
    LC_NUMERIC = "fi_FI.UTF-8";
    LC_PAPER = "fi_FI.UTF-8";
    LC_TELEPHONE = "fi_FI.UTF-8";
    LC_TIME = "fi_FI.UTF-8";
  };

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.xserver.xkb = {
    layout = "fi";
    variant = "";
  };
  console.keyMap = "fi";

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users.${defaultUser} = {
    isNormalUser = true;
    description = defaultUser;
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
    group = defaultUser;
  };
  users.groups.${defaultUser} = {};

  users.users.${kid} = {
    isNormalUser = true;
    description = kid;
    extraGroups = [ "networkmanager" ];
    packages = with pkgs; [
      kdePackages.kate
      prismlauncher
      freetube
      protonup-qt
      heroic
    ];
    group = kid;
  };
  users.groups.${kid} = {};

  services.parentalWatchdog = {
    enable = true;
    instances = {
      ${kid} = {
        default = {
          user = kid;
          limit = 7200;
          warn_before = 900;
          cmd_pattern = "steamapps|PrismLauncher|\\.exe";
          title_pattern = "^Sober$|YouTube";
          time_begin = "12:00";
          time_end = "21:00";
          backend = "kdotool";
          backend_path = "${pkgs.kdotool}/bin/kdotool";
        };
        days = {
          Friday = {
            limit = 10800;
            time_end = "22:00";
          };
          Saturday = {
            limit = 10800;
            time_begin = "9:00";
            time_end = "22:00";
          };
          Sunday = {
            time_begin = "9:00";
          };
        };
      };
    };
  };

  security.sudo.wheelNeedsPassword = false;

  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    htop
    pciutils
    vulkan-tools
  ];

  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.stateVersion = "26.05";

  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  services.flatpak.enable = true;
  programs.steam = {
    enable = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  nix = {
    channel.enable = false;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ "@wheel" ];
    };
  };
}
