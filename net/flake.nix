{
  inputs = {
    nixpkgs.url = "github:matejc/nixpkgs/mylocal277";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };
    upaas = {
      url = "github:matejc/upaas/master";
      # url = "path:/home/matejc/workarea/upaas";
      flake = false;
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, nixos-generators, nixos-hardware, upaas, deploy-rs, ... }: let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    system = "aarch64-linux";
  in {
    nixosConfigurations.net = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hardware-configuration.nix
        "${nixos-hardware}/raspberry-pi/4"
        "${upaas}/module.nix"
        ./configuration.nix
      ];
    };

    deploy-rs = pkgs.deploy-rs.out;
    deploy.nodes.net = {
      sshUser = "matejc";
      user = "root";
      hostname = "192.168.88.128";
      fastConnection = true;
      profiles.system = {
        path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.net;
      };
    };
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    packages.${system} = {
      image = nixos-generators.nixosGenerate {
        inherit system;
        modules = [
          "${nixos-hardware}/raspberry-pi/4"
          "${upaas}/module.nix"
          ./configuration.nix
        ];
        format = "sd-aarch64";
      };
    };
    packages.x86_64-linux = {
      test = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        modules = [
          "${upaas}/module.nix"
          ./configuration.nix
        ];
        format = "vm";
        specialArgs.diskSize = "5000";
      };
    };
  };
}
