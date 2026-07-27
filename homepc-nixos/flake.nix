{
  inputs = {
    nixpkgs.url = "github:matejc/nixpkgs/latest";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    parental-watchdog = {
      url = "github:matejc/parental-watchdog/v0.5.0";
      flake = false;
    };
  };
  outputs = { self, ... }@inputs: let
    system = "x86_64-linux";
  in {
    nixosConfigurations.homepc = inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
      ];
      specialArgs.inputs = inputs;
    };

    deploy.nodes.homepc = {
      sshUser = "matejc";
      user = "root";
      hostname = "192.168.88.21";
      profiles.system = {
        path = inputs.deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.homepc;
      };
    };
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;
  };
}
