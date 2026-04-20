{
  inputs = {
    nixpkgs.url = "github:matejc/nixpkgs/latest";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };
    upaas = {
      url = "github:matejc/upaas/master";
      flake = false;
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, ... }@inputs: let
    system = "x86_64-linux";
  in {
    nixosConfigurations.nixoz = inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        "${inputs.upaas}/module.nix"
        ./hardware-configuration.nix
        ./configuration.nix
      ];
      specialArgs.inputs = inputs;
    };

    deploy.nodes.nixoz = {
      sshUser = "matejc";
      user = "root";
      hostname = "192.168.88.22";
      fastConnection = true;
      profiles.system = {
        path = inputs.deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.nixoz;
      };
    };
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;
  };
}
