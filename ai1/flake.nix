{
  inputs = {
    nixpkgs.url = "github:matejc/nixpkgs/mylocal281";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
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
  outputs = { self, nixpkgs, nixos-generators, upaas, deploy-rs, ... }: let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    system = "x86_64-linux";
  in {
    nixosConfigurations.ai1 = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hardware-configuration.nix
        "${upaas}/module.nix"
        ./configuration.nix
      ];
      specialArgs = { inherit nixpkgs; };
    };

    deploy-rs = pkgs.deploy-rs.out;
    deploy.nodes.ai1 = {
      sshUser = "matejc";
      user = "root";
      hostname = "100.98.35.20";
      profiles.system = {
        path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.ai1;
      };
    };
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    packages.${system} = {
      image = nixos-generators.nixosGenerate {
        inherit system;
        modules = [
          "${upaas}/module.nix"
          ./configuration.nix
        ];
        format = "gce";
      };
    };
  };
}
