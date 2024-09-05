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
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, ... }@inputs: let
    system = "aarch64-linux";
  in {
    nixosConfigurations.printer = inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hardware-configuration.nix
        "${inputs.nixos-hardware}/raspberry-pi/4"
        ./configuration.nix
      ];
    };

    deploy.nodes.printer = {
      sshUser = "matejc";
      user = "root";
      hostname = "192.168.88.129";
      profiles.system = {
        path = inputs.deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.printer;
      };
    };
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;

    packages.${system} = {
      image = inputs.nixos-generators.nixosGenerate {
        inherit system;
        modules = [
          "${inputs.nixos-hardware}/raspberry-pi/4"
          ./configuration.nix
        ];
        format = "sd-aarch64";
      };
    };
    packages.x86_64-linux = {
      test = inputs.nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
        ];
        format = "vm";
        specialArgs.diskSize = "5000";
      };
    };
  };
}
