{ pkgs, lib, config, ... }:
let
  cfgTimers = config.services.piholeSchedule.timers;

  piholeClientSetGroup = pkgs.writeShellScript "pihole-client-set-group.sh" ''
    export PATH="$PATH:${pkgs.lib.makeBinPath [ pkgs.curl pkgs.jq ]}"

    set -e

    pihole_base="$PIHOLE_BASE_URL"
    pihole_password="$PIHOLE_PASSWORD"
    pihole_client="$1"
    pihole_group="$2"

    echo "Setting group '$pihole_group' to device '$pihole_client' ..."

    sid="$(curl -k -s -X POST "$pihole_base/api/auth" --data "{\"password\":\"$pihole_password\"}" | jq -r '.session.sid')"

    cleanup() {
        curl -k -s -X DELETE "$pihole_base/api/auth?sid=$sid"
    }

    trap cleanup EXIT

    groups_output="$(curl -k -s "$pihole_base/api/groups?sid=$sid" -H 'Content-Type: application/json')"
    clients_output="$(curl -k -s "$pihole_base/api/clients/$pihole_client?sid=$sid" -H 'Content-Type: application/json')"
    client_data="$(jq -n -c --argjson clients "$clients_output" --arg client "$pihole_client" '$clients.clients[]|select($client == .client)')"

    client_put_data="$(jq -n -c --argjson groups "$groups_output" --arg group "$pihole_group" --argjson client "$client_data" '$client + {"groups": [$groups.groups[]|select($group == .name)|.id]}')"

    curl -k -s -X PUT "$pihole_base/api/clients/$pihole_client?sid=$sid" --data "$client_put_data" -H 'Content-Type: application/json'

    echo -e "\nGroup '$pihole_group' set to device '$pihole_client'!"
  '';

  piholeClientSetGroupMap = name: pkgs.writeShellScript "pihole-client-set-group-map-${name}.sh" ''
    ${pkgs.lib.concatMapStringsSep "\n" (v: ''
      ${piholeClientSetGroup} "${v.client}" "${v.group}"
    '') cfgTimers.${name}.client_group_map}
  '';

  mkPiholeTimer = name: {
    timers."pihole-schedule-${name}" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfgTimers.${name}.start;
        Persistent = true;
        Unit = "pihole-schedule-${name}.service";
      };
    };
    services."pihole-schedule-${name}" = {
      environment.PIHOLE_BASE_URL = "${config.services.piholeSchedule.apiUrl}";
      serviceConfig = {
        EnvironmentFile = config.services.piholeSchedule.environmentFile;
        ExecStart = "${piholeClientSetGroupMap name}";
        Type = "oneshot";
        User = "pihole";
      };
    };
  };
in
{
  options.services.piholeSchedule = {
    apiUrl = lib.mkOption {
      type = lib.types.str;
      description = "Pihole api url.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Pihole environment variable file, e.g.: PIHOLE_PASSWORD.";
    };
    timers = lib.mkOption {
      type = lib.types.attrs;
      description = "Timers";
      example = {
        kid-freetime = {
          start = "*-*-* 07:00:00";
          client_group_map = [
            { client = "26:8B:9D:7E:25:FB"; group = "Default"; }
          ];
        };
        kid-notime = {
          start = "*-*-* 21:30:00";
          client_group_map = [
            { client = "26:8B:9D:7E:25:FB"; group = "Block"; }
          ];
        };
      };
    };
  };
  config = {
    systemd = lib.mkMerge (lib.mapAttrsToList (n: _: mkPiholeTimer n) cfgTimers);
  };
}
