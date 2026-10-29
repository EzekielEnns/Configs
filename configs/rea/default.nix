# REA (github.com/morluto/rea): reverse-engineering workflows for agents, from JS bundles and
# WASM to native binaries through Ghidra. Run locally; agents use its CLI (`rea`) from bash,
# since Pi has no MCP client. Pinned to the newest release at least two weeks old, like srt;
# package.json is the published one without dev/optional deps and scripts. Upgrades: the
# tool-watch skill (.claude/skills/tool-watch).
{ buildNpmPackage, fetchurl, lib }:

buildNpmPackage rec {
  pname = "rea-agents";
  version = "6.5.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/rea-agents/-/rea-agents-${version}.tgz";
    hash = "sha256-UxcXoG6SymUaq1JpEZD5FvrARCcsAfh14ixeKTIY5pk=";
  };

  postPatch = "cp ${./package.json} package.json; cp ${./package-lock.json} package-lock.json";
  npmDepsHash = "sha256-yegUzb8EoZ2jvYwNxOEMKPQdpHgwQa8OMyfaKeqeWVc=";
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  meta = {
    description = "Reverse engineering workflows for coding agents";
    homepage = "https://github.com/morluto/rea";
    license = lib.licenses.mit;
    mainProgram = "rea";
  };
}
