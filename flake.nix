{
  inputs = {
    nixpkgs.url = "github:matejc/nixpkgs/latest";
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
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    parental-watchdog = {
      url = "github:matejc/parental-watchdog/v0.5.0";
      flake = false;
    };
    nix-matrix-appservices = {
      url = "gitlab:coffeetables/nix-matrix-appservices";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixmy = {
      url = "github:matejc/nixmy/master";
      flake = false;
    };
  };
  outputs = { self, ... }@inputs: let
    defaultSystem = "x86_64-linux";
    pkgs = inputs.nixpkgs.legacyPackages.${defaultSystem};
    lib = pkgs.lib;
    defaultUser = "matejc";
    mkSystem =
      {
        machineName,
        system,
        modules,
      }:
      (inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs machineName defaultUser;
        };
        modules = modules ++ [
          inputs.agenix.nixosModules.default
          ./modules/my.nix
          ./modules/secrets.nix
          (./machines + "/${machineName}/configuration.nix")
          (./machines + "/${machineName}/hardware-configuration.nix")
        ];
      });
    mkDeploy =
      {
        machineName,
        system,
        extraAttrs,
      }: {
        hostname = machineName;  # a hack so that schema check passes, the hostname will be overriden by .#deploy
        sshUser = defaultUser;
        user = "root";
        sshOpts = [];
        profiles.system = {
          path = inputs.deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${machineName};
        };
      } // extraAttrs;
    mkMachineDeploy = machineName: {
      system ? defaultSystem,
      modules ? [ ],
      extraDeployAttrs ? {},
    }: let
      deployChecks = inputs.deploy-rs.lib.${defaultSystem}.deployChecks {
        nodes.${machineName} = self.deploy.nodes.${machineName};
      };
    in {
      nixosConfigurations.${machineName} = mkSystem {
        inherit machineName modules system;
      };
      deploy.nodes.${machineName} = mkDeploy {
        inherit machineName system;
        extraAttrs = extraDeployAttrs;
      };
      checks.${defaultSystem} = {
        "${machineName}-deploy-schema" = deployChecks.deploy-schema;
        "${machineName}-deploy-activate" = deployChecks.deploy-activate;
      };
    };
    machines = {
      nixoz = {
        modules = [
          ./modules/pihole-schedule.nix
          ./modules/mktxp.nix
        ];
      };
      homepc = {
        modules = [
          ./modules/parental-watchdog.nix
        ];
      };
      whirlpool = {
        modules = [
          "${inputs.upaas}/module.nix"
          "${inputs.nixmy}/default.nix"
          inputs.nix-matrix-appservices.nixosModule
        ];
        extraDeployAttrs.sshOpts = [ "-p" "${builtins.getEnv "NIX_SECRET_SSH_PORT"}" ];
      };
    };
  in lib.foldl' lib.recursiveUpdate {} ((lib.mapAttrsToList mkMachineDeploy machines) ++ [{
    apps.${defaultSystem} = {
      ssh = {
        type = "app";
        program = toString (pkgs.writeShellScript "ssh.sh" ''
          set -euo pipefail
          machineName="''${1?"Missing machine name as first arg!"}"
          identityFile="''${2?"Missing SSH identity file as first arg!"}"
          for secretPath in "./machines/$machineName/secrets/"*.age; do
            secretName="$(basename "$secretPath" .age)"
            envName="$(printf 'NIX_SECRET_%s' "$secretName" | tr '[:lower:]-.' '[:upper:]__')"
            envValue="$(${pkgs.age}/bin/age --identity "$identityFile" --decrypt "$secretPath")"
            export "$envName=$envValue"
          done
          export TERM=xterm-256color
          exec ssh -i $identityFile ''${NIX_SECRET_SSH_PORT:+-p "$NIX_SECRET_SSH_PORT"} $NIX_SECRET_SSH_USER@$NIX_SECRET_HOSTNAME -- ''${@:3}
        '');
      };
      deploy = {
        type = "app";
        program = toString (pkgs.writeShellScript "deploy.sh" ''
          set -euo pipefail
          action="''${1?"Missing action (switch/boot/test) as first arg!"}"
          machineName="''${2?"Missing machine name as second arg!"}"
          identityFile="''${3?"Missing SSH identity file as third arg!"}"

          deployArgs=""
          case "$action" in
              switch) ;;
              boot) deployArgs="$deployArgs --boot";;
              test) deployArgs="$deployArgs --test";;
              *)
                  echo "Error: First arg must be one of: switch, boot or test" >&2
                  exit 1
                  ;;
          esac

          hostnamePath="./machines/$machineName/secrets/hostname.age"
          if [[ ! -f "$hostnamePath" ]]; then
            echo "Error: Hostname secret not found: $hostnamePath" >&2
            exit 1
          fi

          for secretPath in "./machines/$machineName/secrets/"*.age; do
            secretName="$(basename "$secretPath" .age)"
            envName="$(printf 'NIX_SECRET_%s' "$secretName" | tr '[:lower:]-.' '[:upper:]__')"
            envValue="$(${pkgs.age}/bin/age --identity "$identityFile" --decrypt "$secretPath")"
            export "$envName=$envValue"
          done

          # pre-check only this machine
          nix build --no-link --impure ".#checks.${defaultSystem}.''${machineName}-deploy-schema"
          nix build --no-link --impure ".#checks.${defaultSystem}.''${machineName}-deploy-activate"

          echo "Deploying $machineName to $NIX_SECRET_HOSTNAME" >&2
          exec ${inputs.deploy-rs.packages.${defaultSystem}.default}/bin/deploy ".#$machineName" --hostname "$NIX_SECRET_HOSTNAME" --skip-checks $deployArgs ''${@:4} -- --impure
        '');
      };
      encrypt = {
        type = "app";
        program = toString (pkgs.writeShellScript "encrypt.sh" ''
          set -euo pipefail
          machineName="''${1?"Missing machine name as first arg!"}"
          secretName="''${2?"Missing secret name as second arg!"}"
          identityFile="''${3?"Missing SSH identity file as third arg!"}"
          if [[ ! -f "$identityFile" ]]; then
            echo "SSH identity file does not exist!" >&2
            exit 1
          fi
          mkdir -p ./machines/$machineName/secrets
          secretPath="./machines/$machineName/secrets/$secretName.age"

          tmpDir="''${XDG_CACHE_DIR:-"$HOME/.cache"}/agenix/$machineName"
          mkdir -p "$tmpDir"
          trap 'rm "$tmpDir/$secretName"; rmdir "$tmpDir"' EXIT

          if [[ -f "$secretPath" ]]; then
            ${pkgs.age}/bin/age --identity "$identityFile" --decrypt "$secretPath" > "$tmpDir/$secretName"
          fi

          "''${EDITOR:-nano}" "$tmpDir/$secretName"

          ${pkgs.age}/bin/age \
            --encrypt \
            --recipients-file ./machines/$machineName/recipients \
            --output "$secretPath" \
            "$tmpDir/$secretName"
        '');
      };
      reencrypt = {
        type = "app";
        program = toString (pkgs.writeShellScript "reencrypt.sh" ''
          set -euo pipefail
          machineName="''${1?"Missing machine name as first arg!"}"
          identityFile="''${2?"Missing SSH identity file as second arg!"}"
          if [[ ! -f "$identityFile" ]]; then
            echo "SSH identity file does not exist!" >&2
            exit 1
          fi

          for file in ./machines/$machineName/secrets/*.age; do
              [ -e "$file" ] || continue
              echo "Re-encrypting: $file" >&2
              ${pkgs.age}/bin/age --decrypt --identity "$identityFile" "$file" | \
                  ${pkgs.age}/bin/age --encrypt --recipients-file ./machines/$machineName/recipients --output "''${file}.new"
              mv "''${file}.new" "$file"
          done
        '');
      };
    };
  }]);
}
