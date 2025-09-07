{
  inputs = {
    nixpkgs.url = "github:matejc/nixpkgs/latest";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
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
    pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
    system = "aarch64-linux";
  in {
    nixosConfigurations.media = inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hardware-configuration.nix
        "${inputs.nixos-hardware}/raspberry-pi/4"
        "${inputs.upaas}/module.nix"
        ./configuration.nix
      ];
      specialArgs.inputs = inputs;
    };

    deploy.nodes.media = {
      sshUser = "matejc";
      user = "root";
      hostname = "192.168.88.25";
      fastConnection = true;
      profiles.system = {
        path = inputs.deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.media;
      };
    };
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;

    packages.${system} = {
      image = inputs.nixos-generators.nixosGenerate {
        inherit system;
        modules = [
          "${inputs.nixos-hardware}/raspberry-pi/4"
          "${inputs.upaas}/module.nix"
          ./configuration.nix
        ];
        format = "sd-aarch64";
        specialArgs.inputs = inputs;
      };
    };
    packages.x86_64-linux = {
      test = inputs.nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        modules = [
          "${inputs.upaas}/module.nix"
          ./configuration.nix
        ];
        format = "vm";
        specialArgs.diskSize = "5000";
        specialArgs.inputs = inputs;
      };
    };
  };
}
