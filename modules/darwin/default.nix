# Darwin platform aggregator: everything every Darwin host gets.
{
  _class = "darwin";

  imports = [
    ./base.nix
    ./defaults.nix
    ./homebrew.nix
    ./nix.nix
    ./shells.nix
  ];
}
