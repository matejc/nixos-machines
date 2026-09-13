{ lib ? (import <nixpkgs> {}).lib, machineName, ... }:
let
  secretFiles = builtins.attrNames (builtins.readDir (./../machines + "/${machineName}/secrets"));

  secretNames =
    map
      (name: lib.removeSuffix ".age" name)
      (builtins.filter
        (name: builtins.match ".*\\.age" name != null)
        secretFiles);

  mkAgeSecrets = names: {
    secrets = lib.genAttrs names (name: {
      file = ./../machines/${machineName}/secrets/${name}.age;
    });
  };
in {
  config = {
    age.identityPaths = lib.mkDefault [
      "/etc/ssh/ssh_host_ed25519_key"
    ];
    age.secrets = (mkAgeSecrets secretNames).secrets;

    _module.args.my = {
      getSecretUnsafe = secretName:
        let
          envName = "NIX_SECRET_${lib.toUpper (lib.replaceStrings [ "-" "." ] [ "_" "_" ] secretName)}";
        in
        builtins.getEnv envName;
      importNixFromSecretUnsafe = secretName: attrs:
        let
          envName = "NIX_SECRET_${lib.toUpper (lib.replaceStrings [ "-" "." ] [ "_" "_" ] secretName)}";
        in
          import (builtins.toFile secretName (builtins.getEnv envName)) attrs;
      cloneSecret = secretName: attrs: {
        file = ./../machines/${machineName}/secrets/${secretName}.age;
      } // attrs;
    };
  };
}
