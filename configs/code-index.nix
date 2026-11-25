# Code indexers for mapping repos into atlas: exact calls from a SCIP indexer where the
# language has one, definitions from Universal Ctags for the 100+ languages it knows.
{ pkgs, ... }:
{
  home.packages = [
    (pkgs.callPackage ./scip-typescript { })
    pkgs.universal-ctags
  ];
}
