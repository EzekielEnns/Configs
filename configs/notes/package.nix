# The notes vault tools (configs/notes): the shared core, the Pi extension, the `notes` CLI
# and the `notes-mcp` server for Claude Code. Node built-ins only; ripgrep and diff are
# pinned here so the tools work in any PATH (Pi's, pis', Claude Code's).
{ stdenvNoCC, makeWrapper, nodejs_22, ripgrep, diffutils }:

stdenvNoCC.mkDerivation {
  pname = "notes-tools";
  version = "1";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/lib/notes $out/bin
    cp core.mjs index.ts notes.mjs mcp.mjs AGENTS.md $out/lib/notes/
    substituteInPlace $out/lib/notes/core.mjs \
      --replace-fail '|| "rg"' '|| "${ripgrep}/bin/rg"' \
      --replace-fail '|| "diff"' '|| "${diffutils}/bin/diff"'
    makeWrapper ${nodejs_22}/bin/node $out/bin/notes --add-flags $out/lib/notes/notes.mjs
    makeWrapper ${nodejs_22}/bin/node $out/bin/notes-mcp --add-flags $out/lib/notes/mcp.mjs
  '';
}
