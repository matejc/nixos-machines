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
  };
  outputs = { self, ... }@inputs: let
    defaultSystem = "x86_64-linux";
    pkgs = inputs.nixpkgs.legacyPackages.${defaultSystem};
    defaultUser = "matejc";
    mkSystem =
      {
        machineName,
        system ? defaultSystem,
        modules ? [ ],
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
          (./. + "/${machineName}/configuration.nix")
          (./. + "/${machineName}/hardware-configuration.nix")
        ];
      });
    mkDeploy =
      {
        machineName,
        system ? defaultSystem,
        extraAttrs ? {},
      }: {
        hostname = machineName;  # a hack so that schema check passes, the hostname will be overriden by .#deploy
        sshUser = defaultUser;
        user = "root";
        profiles.system = {
          path = inputs.deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${machineName};
        };
      } // extraAttrs;
  in {
    nixosConfigurations.nixoz = mkSystem {
      machineName = "nixoz";
      modules = [
        "${inputs.upaas}/module.nix"
        ./modules/pihole-schedule.nix
      ];
    };
    deploy.nodes.nixoz = mkDeploy { machineName = "nixoz"; };

    apps.${defaultSystem} = {
      deploy = {
        type = "app";
        program = toString (pkgs.writeShellScript "deploy.sh" ''
          set -euo pipefail
          machineName="''${1?"Missing machine name as first arg!"}"
          identityFile="''${2?"Missing SSH identity file as second arg!"}"
          hostnamePath="./$machineName/secrets/hostname.age"
          if [[ ! -f "$hostnamePath" ]]; then
            echo "Hostname secret not found: $hostnamePath"
            exit 1
          fi
          for secretPath in "./$machineName/secrets/"*.age; do
            secretName="$(basename "$secretPath" .age)"
            envName="$(printf 'NIX_SECRET_%s' "$secretName" | tr '[:lower:]-' '[:upper:]_')"
            envValue="$(${pkgs.age}/bin/age --identity "$identityFile" --decrypt "$secretPath")"
            export "$envName=$envValue"
          done

          echo "Deploying $machineName to $NIX_SECRET_HOSTNAME"
          exec ${inputs.deploy-rs.packages.${defaultSystem}.default}/bin/deploy ".#$machineName" --hostname "$NIX_SECRET_HOSTNAME" -- --impure
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
          mkdir -p ./$machineName/secrets
          secretPath="./$machineName/secrets/$secretName.age"

          tmpDir="''${XDG_CACHE_DIR:-"$HOME/.cache"}/agenix/$machineName"
          mkdir -p "$tmpDir"
          trap 'rm "$tmpDir/secret"; rmdir "$tmpDir"' EXIT

          if [[ -f "$secretPath" ]]; then
            ${pkgs.age}/bin/age --identity "$identityFile" --decrypt "$secretPath" > "$tmpDir/secret"
          fi

          "''${EDITOR:-nano}" "$tmpDir/secret"

          ${pkgs.age}/bin/age \
            --encrypt \
            --recipients-file ./$machineName/recipients \
            --output "$secretPath" \
            "$tmpDir/secret"
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

          for file in ./$machineName/secrets/*.age; do
              [ -e "$file" ] || continue
              echo "Re-encrypting: $file"
              ${pkgs.age}/bin/age --decrypt --identity "$identityFile" "$file" | \
                  ${pkgs.age}/bin/age --encrypt --recipients-file ./$machineName/recipients --output "''${file}.new"
              mv "''${file}.new" "$file"
          done
        '');
      };
    };
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;
  };
}
