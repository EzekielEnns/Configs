# Sourcegraph's SCIP indexer for TypeScript and JavaScript: the compiler's own answer to
# what calls what, written as index.scip. atlas runs it when mapping a repo, for exact calls
# instead of guesses by name. Not in nixpkgs or Homebrew. 0.6.2 (published 2026-11-10).
# package.json is the published one without devDependencies and scripts (and bin named, so
# it links as scip-typescript, not @sourcegraph), so the lock only
# holds its runtime deps (typescript, svelte2tsx, protobuf).
{ buildNpmPackage, fetchurl, lib }:

buildNpmPackage rec {
  pname = "scip-typescript";
  version = "0.6.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/@sourcegraph/scip-typescript/-/scip-typescript-${version}.tgz";
    hash = "sha256-hfIcsHaXcFB2SL6ENdjr17MEanERccSoHysOgwczTCQ=";
  };

  postPatch = "cp ${./package.json} package.json; cp ${./package-lock.json} package-lock.json";
  npmDepsHash = "sha256-WZyvZ23hJQpVrfGZ9ynrKd+o7BhgZyORX+fBXwsJdSE=";
  dontNpmBuild = true; # ships built JS in dist/

  meta = {
    description = "SCIP indexer for TypeScript and JavaScript";
    homepage = "https://github.com/sourcegraph/scip-typescript";
    license = lib.licenses.asl20;
    mainProgram = "scip-typescript";
  };
}
