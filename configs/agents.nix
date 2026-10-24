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
    { id = "qwen"; name = "Qwen3.6-35B-A3B (2 slots x 32k)"; contextWindow = 32768; maxTokens = 16384; }
    { id = "qwen-27b"; name = "Qwen3.8-27B dense (slow, careful)"; contextWindow = 32768; maxTokens = 16384; }
    { id = "planner"; name = "planner (GLM-5.3 via OpenRouter, US hosts)"; contextWindow = 131072; maxTokens = 32768; }
    # Bake-off contenders (ai-stack docs/BAKEOFF.md)
    { id = "laguna"; name = "Laguna XS 2.1 33B-A3B (Q3)"; contextWindow = 65536; maxTokens = 16384; }
    { id = "gemma"; name = "Gemma 4 26B-A4B (Q4)"; contextWindow = 65536; maxTokens = 16384; }
    { id = "glm-flash"; name = "GLM-4.7-Flash 30B-A3B (Q4)"; contextWindow = 65536; maxTokens = 16384; }
    { id = "devstral"; name = "Devstral Small 2 24B (Q4)"; contextWindow = 65536; maxTokens = 16384; }
  ];
  withReasoning = map (m: m // { reasoning = true; }) models;

  writable = name: file: ''
    run mkdir -p "$(dirname "$HOME/${name}")"
    run install -m 600 ${file} "$HOME/${name}"
  '';

  # Pi's sub-agent extension (shipped as an example in its package): each sub-agent is a
  # separate `pi` process, run alone, in parallel or chained. Its sample agents name
  # Claude models, so ours keep the prompts and use the desktop's.
  piSearxng = pkgs.callPackage ./pi-searxng { };

  subagentDir = "${agentPkgs.pi-coding-agent}/lib/node_modules/pi-monorepo/examples/extensions/subagent";
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
    [ "researcher" "architect" ])
  // lib.listToAttrs (map
    (name: lib.nameValuePair ".pi/agent/prompts/${name}.md" { source = ./pi-agents/${name}.md; })
    [ "research" "research-design-build" ])
  // {
    ".pi/agent/extensions/subagent/index.ts".source = "${subagentDir}/index.ts";
    ".pi/agent/extensions/subagent/agents.ts".source = "${subagentDir}/agents.ts";
    # Web search through the desktop's SearXNG, and page fetch (like Claude's WebFetch).
    ".pi/agent/extensions/searxng".source = "${piSearxng}/lib/node_modules/pi-searxng";
    # Read from ~/.pi, not Pi's agent dir.
    ".pi/searxng.json" = {
      force = true;
      text = builtins.toJSON {
        searxngUrl = "http://${desktop}:8888";
        maxResults = 8;
      };
    };
  };

  piSettings = (pkgs.formats.json { }).generate "pi-settings.json" {
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
