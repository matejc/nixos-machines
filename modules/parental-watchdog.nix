{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.services.parentalWatchdog;

  mkConfigFile = name: config: pkgs.writeTextDir "share/${package.pname}/${name}.yaml" (lib.generators.toYAML {} config);

  mkSystemdService =
    name:
    config:
    let
      configFile = mkConfigFile name config;
    in {
      services."parental-watchdog-${name}" = {
        description = "Parental control app (${name})";
        wantedBy = [ "multi-user.target" ];
        path = with pkgs; [
          util-linux
          procps
          libnotify
          coreutils
        ];
        serviceConfig = {
          Type = "simple";
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/${package.pname}";
          ExecStart = "${package}/bin/${package.pname} run -c ${configFile}/share/${package.pname}/${name}.yaml -a /var/lib/${package.pname}/${name}";
          Restart = "always";
          User = "root";
          Group = "root";
        };
      };
    };

  mkRemainingScript = name: config: pkgs.writeShellScriptBin "${package.pname}-remaining-${name}" ''
    ${package}/bin/${package.pname} time-remaining -c "${configs}/share/${package.pname}/${name}.yaml" -a "/var/lib/${package.pname}/${name}"
  '';

  configs = pkgs.buildEnv {
    name = "${package.pname}-configs";
    paths = lib.mapAttrsToList mkConfigFile cfg.instances;
  };

  remainingScripts = pkgs.buildEnv {
    name = "${package.pname}-scripts";
    paths = lib.mapAttrsToList mkRemainingScript cfg.instances;
  };

  package = pkgs.rustPlatform.buildRustPackage {
    pname = "parental-watchdog";
    version = "dev";
    src = pkgs.fetchFromGitHub {
      owner = "matejc";
      repo = "parental-watchdog";
      tag = "v0.5.2";
      hash = "sha256-5tD4rhtZLr618mZsWJRaP8PWmtNhaVbuqC4PRz2+Epg=";
    };
    cargoHash = "sha256-LHWgUok5qE40HRXXhXTQ1ku6pjL9QFgW9Ws+cUhVc1Q=";
  };

  package-env = pkgs.buildEnv {
    name = "${package.pname}-env";
    paths = [
      package
      configs
      remainingScripts
    ];
  };
in {
  options.services.parentalWatchdog = {
    enable = lib.mkEnableOption "Enable parental watchdog";
    instances = lib.mkOption {
      type = lib.types.attrs;
      description = "Instances configuration";
      example = {
        kid = {
          default = {
            user = "kid";
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
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      package-env
    ];

    systemd = lib.mkMerge (lib.mapAttrsToList mkSystemdService cfg.instances);
  };
}
