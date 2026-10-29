# Anthropic's sandbox runtime (srt): Seatbelt on macOS, bubblewrap on Linux, writes only
# where allowed, chosen paths unreadable, network through its own filtering proxy. Read
# before adopting (2026-10-29): its README and config schema. Pinned to 0.0.79, two weeks
# older than the newest. package.json is the published one without devDependencies and
# scripts, so the lock only holds its four runtime deps. pi-sandbox uses it as a library.
{ buildNpmPackage, fetchurl, lib }:

buildNpmPackage rec {
  pname = "sandbox-runtime";
  version = "0.0.79";

  src = fetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/sandbox-runtime/-/sandbox-runtime-${version}.tgz";
    hash = "sha256-WnMOQ2fCZMzEtZKvAdqwOKbDnbfBhO+9EyhBaI+oVPE=";
  };

  postPatch = "cp ${./package.json} package.json; cp ${./package-lock.json} package-lock.json";
  npmDepsHash = "sha256-o/RnZLi55FF75tk0GDLr76UYTLozKxbA87X+3EgqEww=";
  dontNpmBuild = true; # ships built JS in dist/

  meta = {
    description = "OS-level sandbox for agents and commands (Seatbelt / bubblewrap + network proxy)";
    homepage = "https://github.com/anthropics/sandbox-runtime";
    license = lib.licenses.asl20;
    mainProgram = "srt";
  };
}
