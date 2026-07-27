{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  vars = import ./vars.nix { inherit pkgs; };

  mkConfigFile = name: config: pkgs.writeTextDir "share/${package.pname}/${name}.yaml" (lib.generators.toYAML {} (lib.recursiveUpdate config {
    default = {
      backend = "kdotool";
      backend_path = "${pkgs.kdotool}/bin/kdotool";
    };
  }));

  mkSystemdService =
    name:
    config:
    let
      configFile = mkConfigFile name config;
    in {
      systemd.services."parental-watchdog-${name}" = {
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
    paths = lib.mapAttrsToList mkConfigFile vars.parental-watchdog.instances;
  };

  remainingScripts = pkgs.buildEnv {
    name = "${package.pname}-scripts";
    paths = lib.mapAttrsToList mkRemainingScript vars.parental-watchdog.instances;
  };

  package = pkgs.rustPlatform.buildRustPackage {
    pname = "parental-watchdog";
    version = "dev";
    src = inputs.parental-watchdog;
    cargoHash = "sha256-I+Fel93IYBa3zcK5kMWVZ1zJAh0UMUljYNlkr4V3OpE=";
  };

  package-env = pkgs.buildEnv {
    name = "${package.pname}-env";
    paths = [
      package
      configs
      remainingScripts
    ];
  };
in lib.mkMerge ([{
  environment.systemPackages = [
    package-env
  ];
}] ++ (lib.mapAttrsToList mkSystemdService vars.parental-watchdog.instances))
