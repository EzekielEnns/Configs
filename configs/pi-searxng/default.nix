# pi-searxng: Pi extension with web_search (SearXNG) and fetch_content (page → Markdown,
# GitHub links cloned). Read before adopting (2026-10-24): talks only to SearXNG and the
# URLs it's asked to fetch. Its peer deps (Pi itself, typebox) are provided by Pi at
# runtime, so the lock file skips them (npm --legacy-peer-deps).
{ buildNpmPackage, fetchurl, lib }:

buildNpmPackage rec {
  pname = "pi-searxng";
  version = "1.0.4";

  src = fetchurl {
    url = "https://registry.npmjs.org/pi-searxng/-/pi-searxng-${version}.tgz";
    hash = "sha256-s+PqqA9pJL3qjzO+cryZMOV48lWrjQE5TLobZxiSzhQ=";
  };

  postPatch = "cp ${./package-lock.json} package-lock.json";
  npmDepsHash = "sha256-4bOi/VXms6arsfy5d9pegHWFTvZGB0I4QaCBlGUEwK4=";
  npmFlags = [ "--legacy-peer-deps" ];
  dontNpmBuild = true; # plain TypeScript, loaded by Pi directly

  meta = {
    description = "SearXNG web search and page fetch tools for Pi";
    homepage = "https://github.com/jcha0713/pi-searxng";
    license = lib.licenses.mit;
  };
}
