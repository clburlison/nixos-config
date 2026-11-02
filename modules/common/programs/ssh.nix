{
  config,
  lib,
  pkgs,
  ...
}:

let
  # The activation appends one key; keep lib/ssh-keys.nix to a single entry
  # or extend this script.
  sshKeys = import ../../../lib/ssh-keys.nix;
in
{
  _class = "homeManager";

  home.activation.authorizeSshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    sshDir="${config.home.homeDirectory}/.ssh"
    authorizedKeys="$sshDir/authorized_keys"
    key=${lib.escapeShellArg (lib.head sshKeys)}

    ${pkgs.coreutils}/bin/install -d -m 700 "$sshDir"
    if [ ! -e "$authorizedKeys" ]; then
      ${pkgs.coreutils}/bin/touch "$authorizedKeys"
    fi
    ${pkgs.coreutils}/bin/chmod 600 "$authorizedKeys"
    if ! ${pkgs.gnugrep}/bin/grep -Fqx "$key" "$authorizedKeys"; then
      printf '%s\n' "$key" >> "$authorizedKeys"
    fi
  '';
}
