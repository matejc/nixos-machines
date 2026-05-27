{
  inputs = {
    nixpkgs.url = "github:matejc/nixpkgs/latest";
    upaas = {
      url = "github:matejc/upaas/master";
      flake = false;
    };
    nixmy = {
      url = "github:matejc/nixmy/master";
      flake = false;
    };
    helper_scripts = {
      url = "github:matejc/helper_scripts/master";
      flake = false;
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-matrix-appservices = {
      url = "gitlab:coffeetables/nix-matrix-appservices";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs { inherit system; };
      deployPkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          inputs.deploy-rs.overlays.default
          (self: super: {
            deploy-rs = {
              inherit (pkgs) deploy-rs;
              lib = super.deploy-rs.lib;
            };
          })
        ];
      };
      vars = pkgs.callPackage ./vars.nix { };
      machines = {
        whirlpool = {
          hostname = vars.hostname;
          sshUser = vars.user;
          sshPort = vars.sshPort;
          inherit system vars;
          modules = [
            inputs.nix-matrix-appservices.nixosModule
            inputs.nix-minecraft.nixosModules.minecraft-servers
            {
              nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];
              nixpkgs.config.allowUnfreePredicate =
                pkg:
                builtins.elem (pkgs.lib.getName pkg) [
                  "minecraft-server"
                ];
            }
            ./mc.nix
            vars.config
          ];
        };
      };
      mkMachine =
        {
          name,
          extraSshOpts ? [ ],
          ...
        }@args:
        {
          sshUser = args.sshUser;
          user = "root";
          sshOpts = [
            "-p"
            "${toString args.sshPort}"
          ]
          ++ extraSshOpts;
          inherit (args) hostname;
          profiles.system = {
            path = deployPkgs.deploy-rs.lib.activate.nixos (
              inputs.nixpkgs.lib.nixosSystem {
                inherit system;
                modules = [
                  "${inputs.upaas}/module.nix"
                  "${inputs.nixmy}/default.nix"
                  ./hardware-configuration.nix
                  ./configuration.nix
                ]
                ++ args.modules;
                specialArgs = { inherit inputs args; };
              }
            );
          };
        };
    in
    {
      checks = builtins.mapAttrs (
        system: deployLib: deployLib.deployChecks self.deploy
      ) inputs.deploy-rs.lib;
      deploy.nodes = builtins.mapAttrs (name: v: mkMachine ({ inherit name; } // v)) machines;
    };
}
