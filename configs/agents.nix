# Pi, the coding agent, pointed at the AI gateway on the desktop (LiteLLM :4000, see
# nixos/dk.nix services.ai-stack). Shared by the Mac and the desktop. (omp was tried and
# dropped 2026-10-24: its input bar can't be a closed box; see git history for its config.)
{ lib, pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;

  # The gateway listens only on the desktop's Tailscale IP, and the desktop doesn't
  # resolve its own MagicDNS name.
  desktop = if pkgs.stdenv.isDarwin then "desktop" else "100.64.96.125";
  gateway = "http://${desktop}:4000/v1";

  # Pi from its own nixpkgs pin: our pinned unstable still has Pi 0.80.
  agentPkgs = inputs.pi-nixpkgs.legacyPackages.${system};

  models = [
    # Flint runs 2 slots x 32k on the desktop so two (sub-)agents work at once.
    { id = "flint"; name = "Flint 40B-A2.5B (quick: 2k thinking)"; contextWindow = 32768; maxTokens = 16384; }
    { id = "flint-careful"; name = "Flint 40B-A2.5B (careful: no thinking cap)"; contextWindow = 32768; maxTokens = 16384; }
    { id = "planner"; name = "planner (GLM-5.3 via OpenRouter, US hosts)"; contextWindow = 131072; maxTokens = 32768; }
    # Research (ai-stack docs/models/sage-a1.5.md): Sage runs its own sub-agents, 2 slots
    # x 32k; the 4B runs 4 slots x 16k for quick lookups.
    { id = "sage"; name = "Sage-A1.5 35B-A3B (research, Q3, 2 slots x 32k)"; contextWindow = 32768; maxTokens = 16384; }
    { id = "agents-a1-4b"; name = "Agents-A1 4B (research, 4 slots x 16k)"; contextWindow = 16384; maxTokens = 8192; }
    # Coding bake-off against Flint (ai-stack docs/BAKEOFF.md)
    { id = "laguna"; name = "Laguna XS 2.1 33B-A3B (Q3)"; contextWindow = 65536; maxTokens = 16384; }
  ];
  withReasoning = map (m: m // { reasoning = true; }) models;

  writable = name: file: ''
    run mkdir -p "$(dirname "$HOME/${name}")"
    run install -m 600 ${file} "$HOME/${name}"
  '';

  # Web tools: pi-searxng's search config and page extraction, with our index.ts
  # (pi-extensions/web): pages are saved to files and the model gets an outline + path to
  # grep, instead of 30k chars inline; GitHub links fetch raw files instead of cloning.
  piSearxng = (pkgs.callPackage ./pi-searxng { }).overrideAttrs (old: {
    postPatch = old.postPatch + "\ncp ${./pi-extensions/web/index.ts} index.ts";
    # Not in the package's `files` list, so npm's install would leave it out.
    postInstall = "cp -r ${./pi-extensions/web/steps} $out/lib/node_modules/pi-searxng/steps";
  });

  # Pi's sub-agent extension (shipped as an example in its package): each sub-agent is a
  # separate `pi` process, run alone, in parallel or chained. Its sample agents name
  # Claude models, so ours keep the prompts and use the desktop's. Patched
  # (pi-extensions/subagent.patch) for our 2 llama.cpp slots: at most 2 run at once across
  # calls, per-agent thinking / tool budget / timeout, a shared run directory for notes and
  # pages, and saved notes returned even when an agent dies.
  subagentDir = pkgs.applyPatches {
    name = "pi-subagent";
    src = "${agentPkgs.pi-coding-agent}/lib/node_modules/pi-monorepo/examples/extensions/subagent";
    patches = [ ./pi-extensions/subagent.patch ];
  };
  subagentModels = {
    scout = "desktop/flint";
    worker = "desktop/flint";
    planner = "desktop/flint-careful";
    reviewer = "desktop/flint-careful";
  };
  subagentFiles = lib.mapAttrs'
    (name: model: lib.nameValuePair ".pi/agent/agents/${name}.md" {
      text = builtins.replaceStrings [ "\nmodel: claude-sonnet-4-5\n" "\nmodel: claude-haiku-4-5\n" ]
        [ "\nmodel: ${model}\n" "\nmodel: ${model}\n" ]
        (builtins.readFile "${subagentDir}/agents/${name}.md");
    })
    subagentModels
  // lib.listToAttrs (map
    (name: lib.nameValuePair ".pi/agent/prompts/${name}.md" { source = "${subagentDir}/prompts/${name}.md"; })
    [ "implement" "implement-and-review" "scout-and-plan" ])
  # Ours (configs/pi-agents): researcher + architect, and the /research and
  # /research-design-build workflows built on them.
  // lib.listToAttrs (map
    (name: lib.nameValuePair ".pi/agent/agents/${name}.md" { source = ./pi-agents/${name}.md; })
    [ "researcher" "researcher-fast" "architect" ])
  // lib.listToAttrs (map
    (name: lib.nameValuePair ".pi/agent/prompts/${name}.md" { source = ./pi-agents/${name}.md; })
    [ "research" "research-fast" "research-design-build" "lookup" ])
  // {
    ".pi/agent/extensions/subagent/index.ts".source = "${subagentDir}/index.ts";
    ".pi/agent/extensions/subagent/agents.ts".source = "${subagentDir}/agents.ts";
    # Small-context helpers (pi-extensions): big tool output to files, and for research
    # sub-agents only, a tool budget plus the note and code_search tools.
    ".pi/agent/extensions/spill.ts".source = ./pi-extensions/spill.ts;
    ".pi/agent/extensions/budget.ts".source = ./pi-extensions/budget.ts;
    ".pi/agent/extensions/research.ts".source = ./pi-extensions/research.ts;
    # Web search through the desktop's SearXNG, and page fetch (like Claude's WebFetch).
    ".pi/agent/extensions/searxng".source = "${piSearxng}/lib/node_modules/pi-searxng";
    # Read from ~/.pi, not Pi's agent dir.
    ".pi/searxng.json" = {
      force = true;
      text = builtins.toJSON {
        # web_search / lookup try these in order (pi-extensions/web/steps/search.ts):
        # Brave and SearXNG through the gateway (keys stay in the desktop's secrets.env),
        # then SearXNG directly with the engines that answer from a home IP.
        searchChain = [ "gateway:brave" "gateway:searxng" "searxng" ];
        gatewayUrl = "http://${desktop}:4000";
        searxngUrl = "http://${desktop}:8888";
        searxngEngines = "yahoo,wikipedia,github";
        maxResults = 8;
      };
    };
  };

  piSettings = (pkgs.formats.json { }).generate "pi-settings.json" {
    # Start on Flint and only cycle desktop models. Without this Pi picks "automatic",
    # and modules/nvim.nix's dummy OPENAI_API_KEY (for aider) makes that OpenAI.
    defaultProvider = "desktop";
    defaultModel = "flint";
    enabledModels = [ "desktop/*" ];
    # Pi's compaction defaults (start when <16k free, keep the last 20k) assume big
    # windows; on 16-32k slots they'd compact at half full and keep more than fits.
    # Use a quarter of the window for each instead.
    compaction.modelOverrides = lib.listToAttrs (map
      (m: lib.nameValuePair "desktop/${m.id}" {
        reserveTokens = m.contextWindow / 4;
        keepRecentTokens = m.contextWindow / 4;
      })
      (lib.filter (m: m.contextWindow <= 32768) models));
    hideThinkingBlock = true; # Ctrl+T shows it
    showHardwareCursor = true; # Pi's drawn cursor looked squished
    editorPaddingX = 1;
  };
in
{
  home.packages = [ agentPkgs.pi-coding-agent ];

  home.file = subagentFiles // {
    ".pi/agent/models.json" = {
      force = true;
      source = (pkgs.formats.json { }).generate "pi-models.json" {
        providers.desktop = {
          baseUrl = gateway;
          api = "openai-completions";
          apiKey = "local";
          models = withReasoning;
        };
      };
    };
  };

  # Pi writes lastChangelogVersion into its settings, so it needs a writable copy.
  home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (writable ".pi/agent/settings.json" piSettings);
}
