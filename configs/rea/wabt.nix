# wabt 1.0.42: REA's inspect-wasm-artifact checks for exactly this version; nixpkgs has 1.0.37.
{ wabt, fetchFromGitHub, lib }:

wabt.overrideAttrs (old: rec {
  version = "1.0.42";
  src = fetchFromGitHub {
    owner = "WebAssembly";
    repo = "wabt";
    rev = version;
    hash = "sha256-33XpYt42Jw2xfwBR64jVI3VYVIKD1YjND9SSI6CdkaM=";
    fetchSubmodules = true;
  };
})
