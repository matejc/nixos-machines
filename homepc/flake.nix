{
  inputs = {
    nixpkgs.url = "github:matejc/nixpkgs/latest";
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    parental-watchdog = {
      url = "github:matejc/parental-watchdog/v0.2.0";
      flake = false;
    };
  };
  outputs =
    { self, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs { inherit system; };
      parental-watchdog = pkgs.callPackage ./parental-watchdog.nix {
        instances = (import ./vars.nix).parental-watchdog.instances;
        parental-watchdog-src = inputs.parental-watchdog;
      };
    in
    {
      packages.${system}.parental-watchdog = parental-watchdog;

      deploy-rs = pkgs.deploy-rs.out;

      deploy.nodes.homepc = {
        sshUser = "root";
        user = "root";
        hostname = "192.168.88.127";
        autoRollback = false;
        profiles.parental-watchdog = {
          path =
            inputs.deploy-rs.lib.${system}.activate.custom parental-watchdog
              "${parental-watchdog}/bin/parental-watchdog-activate";
          profilePath = "/nix/var/nix/profiles/parental-watchdog";
        };
      };

      checks = builtins.mapAttrs (
        system: deployLib: deployLib.deployChecks self.deploy
      ) inputs.deploy-rs.lib;
    };
}
