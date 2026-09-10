{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.mktxp;

  version = "2.0.3";
  package = pkgs.python3Packages.buildPythonApplication {
    pname = "mktxp";
    inherit version;
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "akpw";
      repo = "mktxp";
      tag = "v${version}";
      hash = "sha256-6CVVYBQWsEiFuJSeEiXAtsWuAKWBGrSFCT8xzCW5QrQ=";
    };

    build-system = with pkgs.python3Packages; [ setuptools ];

    dependencies = with pkgs.python3Packages; [
      prometheus-client
      routeros-api
      configobj
      humanize
      texttable
      speedtest-cli
      waitress
      packaging
      pyyaml
    ];

    nativeCheckInputs = with pkgs.python3Packages; [
      pytestCheckHook
      pytest-mock
    ];

    # tests create the mktxp config under $HOME
    preCheck = ''
      export HOME=$(mktemp -d)
    '';

    pythonImportsCheck = [ "mktxp" ];
  };
in {
  options.services.mktxp = {
    enable = lib.mkEnableOption "Enable prometheus mktxp exporter";
    package = lib.mkOption {
      description = "mktxp package";
      type = lib.types.package;
      default = package;
    };
    listenAddress = lib.mkOption {
      description = "Listening address";
      type = lib.types.str;
      default = "127.0.0.1";
    };
    listenPort = lib.mkOption {
      description = "Listening port";
      type = lib.types.int;
      default = 49090;
    };
    configFile = lib.mkOption {
      description = "mktxp.conf";
      type = lib.types.either lib.types.str lib.types.path;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];

    environment.etc."mktxp/mktxp.conf" = {
      source = cfg.configFile;
      user = "mktxp";
      group = "mktxp";
      mode = "0500";
    };

    environment.etc."mktxp/_mktxp.conf" = {
      text = ''
        [MKTXP]
            listen = ${cfg.listenAddress}:${toString cfg.listenPort}          # Listen address (IPv4 and IPv6)
            socket_timeout = 2               # Socket connection timeout in seconds
            initial_delay_on_failure = 120   # Backoff delay when router is unreachable
            max_delay_on_failure = 900
            bandwidth = False                # Built-in periodic bandwidth testing
            compact_default_conf_values = True
      '';
      user = "mktxp";
      group = "mktxp";
      mode = "0500";
    };

    systemd.services.mktxp = {
      description = "MKTXP MikroTik Prometheus Exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      script = ''
        ${cfg.package}/bin/mktxp --cfg-dir /etc/mktxp export
      '';
      serviceConfig = {
        User = "mktxp";
        Group = "mktxp";
        Restart = "always";
        RestartSec = "5s";
      };
    };

    users.users.mktxp = {
      isSystemUser = true;
      createHome = false;
      group = "mktxp";
    };
    users.groups.mktxp = { };
  };
}
