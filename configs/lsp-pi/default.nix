# lsp-pi: an `lsp` tool for Pi (definitions, references, hover, rename, symbols, diagnostics)
# on the language servers already installed (typescript-language-server, basedpyright,
# gopls, rust-analyzer). Read before adopting (2026-10-29): it only spawns those servers,
# except a Kotlin server it would download from JetBrains at runtime, which is patched out.
# Its after-edit diagnostics are off in settings.json: check.ts already reports compile
# errors. package.json is the published one without dev/peer deps (Pi provides those), and
# vscode-languageserver-protocol pinned to 3.17.5: 3.18 drops the "/node.js" path it imports.
# Upgrades: the tool-watch skill.
{ buildNpmPackage, fetchurl, lib }:

buildNpmPackage rec {
  pname = "lsp-pi";
  version = "1.0.5";

  src = fetchurl {
    url = "https://registry.npmjs.org/lsp-pi/-/lsp-pi-${version}.tgz";
    hash = "sha256-6xtaXAseK9d/zowUlOvUjIV2v+KOWFtolLJNn8MaAjg=";
  };

  postPatch = ''
    cp ${./package.json} package.json; cp ${./package-lock.json} package-lock.json
    substituteInPlace lsp-core.ts \
      --replace-fail 'const res = await fetch("https://api.github.com/repos/Kotlin/kotlin-lsp/releases/latest"' \
                     'return undefined; const res = await fetch("https://api.github.com/repos/Kotlin/kotlin-lsp/releases/latest"' \
      --replace-fail 'spawn: simpleSpawn("pyright-langserver")' 'spawn: simpleSpawn("basedpyright-langserver")'
    # Without a UI (pi -p, unattended runs) nothing follows the agent's last turn, but the
    # language servers kept Pi from exiting: stop them there.
    substituteInPlace lsp.ts \
      --replace-fail 'pi.on("agent_end", async (event, ctx) => {' \
                     'pi.on("agent_end", async (event, ctx) => { if (!ctx.hasUI) { clearIdleShutdownTimer(); await shutdownManager(); activeClients.clear(); return; }'
    # lsp-tool.ts is loaded as its own extension with its own copy of lsp-core's manager,
    # and the servers the tool starts belong to that copy.
    substituteInPlace lsp-tool.ts \
      --replace-fail 'import { getOrCreateManager,' 'import { shutdownManager, getOrCreateManager,' \
      --replace-fail 'export default function (pi: ExtensionAPI) {' \
                     'export default function (pi: ExtensionAPI) { pi.on("agent_end", async (_e, ctx) => { if (!ctx.hasUI) await shutdownManager(); });'
  '';
  npmDepsHash = "sha256-j0mZeZi81cxTpCrSrjMJhV0lo0yDkWEox22hRqqg+1s=";
  dontNpmBuild = true; # plain TypeScript, loaded by Pi directly

  meta = {
    description = "Language server tool and diagnostics for Pi";
    license = lib.licenses.mit;
  };
}
