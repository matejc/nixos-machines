{ lib, ... }:
{
  _module.args.my = {
    readFileTrim = file:
      lib.strings.trim (builtins.readFile file);
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
  };
}
