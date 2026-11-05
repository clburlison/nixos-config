# Declares the host identity options set by the builders from the Host table.
# Imported by both the system and Home Manager builders.
{ lib, ... }:

{
  options.clb.host = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "Host name from the Host table.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      description = "Primary user of the host.";
    };
  };
}
