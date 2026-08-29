{ lib, ... }:
{
  _module.args.my = {
    readFileTrim = file:
      lib.strings.trim (builtins.readFile file);
    getSecret = secretName:
      let
        envName = "NIX_SECRET_${lib.toUpper (lib.replaceStrings [ "-" "." ] [ "_" "_" ] secretName)}";
      in
      builtins.getEnv envName;
  };
}
