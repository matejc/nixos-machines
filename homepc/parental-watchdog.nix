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
  mkSystemdService =
    name:
    {
      user,
      limit ? 7200,
      warn-before ? 900,
      backend ? "kdotool",
      cmd-pattern ? "",
      title-pattern ? "",
      time-begin ? "6:00",
      time-end ? "21:00",
    }:
    writeTextDir "share/${package.pname}/parental-watchdog-${name}.service" ''
      [Unit]
      Description=Parental control app (${name})
      After=multi-user.target

      [Service]
      Type=simple
      ExecStart=${package}/bin/${package.pname} --user ${user} --apps-file "/root/.local/state/parental-watchdog-${name}" --backend ${backend} ${
        if cmd-pattern != "" then "--cmd-pattern '${cmd-pattern}'" else ""
      } ${
        if title-pattern != "" then "--title-pattern '${title-pattern}'" else ""
      } --limit ${toString limit} --warn-before ${toString warn-before} --time-begin ${time-begin} --time-end ${time-end}
      Environment=PATH=${
        lib.makeBinPath [
          kdotool
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

  services = buildEnv {
    name = "${package.pname}-services";
    paths = lib.mapAttrsToList mkSystemdService instances;
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
    cargoHash = "sha256-bZKKqhCEI2AFJv9ug3/5qmkT4cDSHj/B+B9ilG0Jewc=";
  };
in
buildEnv {
  name = "${package.pname}-env";
  paths = [
    kdotool
    package
    activationScript
    services
  ];
}
