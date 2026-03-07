{
  rustPlatform,
  kdotool,
  writeShellScriptBin,
  instances,
  writeTextDir,
  lib,
  buildEnv,
  util-linux,
  procps,
  libnotify,
  parental-watchdog-src,
}:
let
  mkConfigFile = name: config: writeTextDir "share/${package.pname}/${name}.yaml" (lib.generators.toYAML {} (config // {
    user = config.user;
    backend = "kdotool";
    backend_path = "${kdotool}/bin/kdotool";
  }));
  mkSystemdService =
    name:
    config:
    let
      configFile = mkConfigFile name config;
    in
    writeTextDir "share/${package.pname}/parental-watchdog-${name}.service" ''
      [Unit]
      Description=Parental control app (${name})
      After=multi-user.target

      [Service]
      Type=simple
      ExecStartPre=mkdir -p /var/lib/${package.pname}
      ExecStart=${package}/bin/${package.pname} run -c "${configFile}/share/${package.pname}/${name}.yaml" -a "/var/lib/${package.pname}/${name}"
      Environment=PATH=${
        lib.makeBinPath [
          util-linux
          procps
          libnotify
        ]
      }
      Restart=always
      User=root
      Group=root

      [Install]
      WantedBy=multi-user.target
    '';

  mkRemainingScript = name: config: writeShellScriptBin "${package.pname}-remaining-${name}" ''
    ${package}/bin/${package.pname} time-remaining -c "${configs}/share/${package.pname}/${name}.yaml" -a "/var/lib/${package.pname}/${name}"
  '';

  services = buildEnv {
    name = "${package.pname}-services";
    paths = lib.mapAttrsToList mkSystemdService instances;
  };

  configs = buildEnv {
    name = "${package.pname}-configs";
    paths = lib.mapAttrsToList mkConfigFile instances;
  };

  remainingScripts = buildEnv {
    name = "${package.pname}-scripts";
    paths = lib.mapAttrsToList mkRemainingScript instances;
  };

  activationScript = writeShellScriptBin "parental-watchdog-activate" ''
    export PATH="$PATH:/usr/bin"

    for unit in $(systemctl list-units --type=service --all --no-legend --no-pager | grep -Eo '(${package.pname}-[^ ]+.service)')
    do
        systemctl disable --now "$unit" || true
    done

    systemctl enable --now ${services}/share/${package.pname}/${package.pname}-*.service
  '';

  package = rustPlatform.buildRustPackage {
    pname = "parental-watchdog";
    version = "dev";
    src = parental-watchdog-src;
    cargoHash = "sha256-BZGoRiRB5yRZc0FghHriRvbijRv3smyFKO9lk8cBqH8=";
  };
in
buildEnv {
  name = "${package.pname}-env";
  paths = [
    package
    activationScript
    services
    configs
    remainingScripts
  ];
}
