# System secrets from the 1Password Agents vault, read with the host's one
# sops-nix secret: the `agents` service account token. op-agents.service
# writes each secret in clb.opAgents.secrets to /run/op-agents/<name> (tmpfs)
# at boot, before the services that read it, and refreshes hourly, restarting
# those services when a value changes. The host sets sops.defaultSopsFile to
# the file holding the token. See docs/op-agents.md.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.clb.opAgents;
  dir = "/run/op-agents";
  tokenFile = config.sops.secrets.op-agents-token.path;
  services = lib.unique (lib.concatMap (s: s.services) (lib.attrValues cfg.secrets));

  fetch = pkgs.writeShellApplication {
    name = "op-agents-fetch";
    runtimeInputs = [
      pkgs._1password-cli
      pkgs.coreutils
      pkgs.diffutils
      pkgs.systemd
    ];
    text = ''
      OP_SERVICE_ACCOUNT_TOKEN="$(cat ${tokenFile})"
      export OP_SERVICE_ACCOUNT_TOKEN
      export OP_CONFIG_DIR=/run/op-agents-config
      install -d -m 0700 "$OP_CONFIG_DIR"

      # At boot the network may not be up yet.
      for attempt in $(seq 1 40); do
        op whoami >/dev/null 2>&1 && break
        [ "$attempt" -eq 40 ] && { echo "op whoami failed; check ${tokenFile} and the network" >&2; exit 1; }
        sleep 15
      done

      failures=0
      restart=()
      ${lib.concatMapStrings (
        name:
        let
          s = cfg.secrets.${name};
          read =
            if s.reference != null then
              "op read --no-newline ${lib.escapeShellArg s.reference}"
            else
              "op inject --in-file ${pkgs.writeText "op-agents-${name}.tpl" s.template}";
        in
        ''
          tmp="$(mktemp ${dir}/.${name}.XXXXXX)"
          if ${read} >"$tmp"; then
            chown ${s.owner}:${s.group} "$tmp"
            chmod ${s.mode} "$tmp"
            if cmp -s "$tmp" ${s.path}; then
              rm -f "$tmp"
            else
              mv -f "$tmp" ${s.path}
              restart+=(${lib.escapeShellArgs s.services})
              echo "updated ${name}"
            fi
          else
            rm -f "$tmp"
            echo "failed to read ${name}" >&2
            failures=$((failures + 1))
          fi
        ''
      ) (lib.attrNames cfg.secrets)}

      # --no-block: at boot those services wait on this one. try-restart
      # leaves stopped services alone.
      if [ "''${#restart[@]}" -gt 0 ]; then
        systemctl --no-block try-restart "''${restart[@]}"
      fi
      [ "$failures" -eq 0 ]
    '';
  };
in
{
  _class = "nixos";

  options.clb.opAgents.secrets = lib.mkOption {
    description = "Agents vault secrets written to ${dir}/<name>.";
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            reference = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "op://Agents/CLIProxyAPI/cliproxyapi-api-key";
              description = "1Password secret reference. Set this or template.";
            };
            template = lib.mkOption {
              type = lib.types.nullOr lib.types.lines;
              default = null;
              example = "API_KEY={{ op://Agents/item/field }}";
              description = "File content with {{ op://... }} references, filled in by `op inject`.";
            };
            owner = lib.mkOption {
              type = lib.types.str;
              default = "root";
            };
            group = lib.mkOption {
              type = lib.types.str;
              default = "root";
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "0400";
            };
            services = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "systemd services that read it: started after it, restarted when it changes.";
            };
            path = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              default = "${dir}/${name}";
            };
          };
        }
      )
    );
  };

  config = {
    assertions = lib.mapAttrsToList (name: s: {
      assertion = (s.reference == null) != (s.template == null);
      message = "clb.opAgents.secrets.${name}: set exactly one of reference and template.";
    }) cfg.secrets;

    # The host's one secret. Readable by the host user for agent-git and
    # op-agents in Home Manager (modules/common/programs/op-agents.nix).
    sops.secrets.op-agents-token = {
      owner = config.clb.host.user;
      mode = "0400";
    };

    systemd.services = lib.mkMerge (
      [
        {
          op-agents = {
            description = "Fetch secrets from the 1Password Agents vault";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = lib.getExe fetch;
              RuntimeDirectory = "op-agents";
              RuntimeDirectoryMode = "0755";
              # Keep the files when this restarts, e.g. on a switch.
              RuntimeDirectoryPreserve = "yes";
              TimeoutStartSec = "15min";
            };
          };

          op-agents-refresh = {
            description = "Refresh secrets from the 1Password Agents vault";
            after = [ "op-agents.service" ];
            requisite = [ "op-agents.service" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = lib.getExe fetch;
            };
          };
        }
      ]
      ++ map (name: {
        ${name} = {
          after = [ "op-agents.service" ];
          requires = [ "op-agents.service" ];
        };
      }) services
    );

    # Service accounts are rate limited, so hourly.
    systemd.timers.op-agents-refresh = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnUnitActiveSec = "1h";
        OnActiveSec = "1h";
      };
    };
  };
}
