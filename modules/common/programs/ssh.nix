{
  config,
  lib,
  pkgs,
  ...
}:

let
  sshKeys = import ../../../lib/ssh-keys.nix;
in
{
  _class = "homeManager";

  home.activation.authorizeSshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    sshDir="${config.home.homeDirectory}/.ssh"
    authorizedKeys="$sshDir/authorized_keys"

    ${pkgs.coreutils}/bin/install -d -m 700 "$sshDir"
    if [ ! -e "$authorizedKeys" ]; then
      ${pkgs.coreutils}/bin/touch "$authorizedKeys"
    fi
    ${pkgs.coreutils}/bin/chmod 600 "$authorizedKeys"
    for key in ${lib.escapeShellArgs sshKeys}; do
      if ! ${pkgs.gnugrep}/bin/grep -Fqx "$key" "$authorizedKeys"; then
        printf '%s\n' "$key" >> "$authorizedKeys"
      fi
    done
  '';
}
