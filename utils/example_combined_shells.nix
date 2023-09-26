{ pkgs ? import <nixpkgs> {} }:
let 
    project =    (import ./default.nix { inherit pkgs; });
    personal =     (import ./../../shell.nix { inherit pkgs; });
in
pkgs.mkShell {
  nativeBuildInputs = [
    project.nativeBuildInputs 
    personal.nativeBuildInputs
  ];
  shellHook = project.shellHook + personal.shellHook; 
}
