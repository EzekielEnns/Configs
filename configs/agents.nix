# Coding agents (omp, Pi) pointed at the AI gateway on the desktop (LiteLLM :4000, see
# nixos/dk.nix services.ai-stack). Shared by the Mac and the desktop.
{ lib, pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;

  # The gateway listens only on the desktop's Tailscale IP, and the desktop doesn't
  # resolve its own MagicDNS name.
  gateway = "http://${if pkgs.stdenv.isDarwin then "desktop" else "100.64.96.125"}:4000/v1";

  # Pi from the nixpkgs omp builds with: our pinned unstable still has Pi 0.80.
  agentPkgs = inputs.omp.inputs.nixpkgs.legacyPackages.${system};

  models = [
    { id = "flint"; name = "Flint 40B-A2.5B (quick: 2k thinking)"; contextWindow = 65536; maxTokens = 16384; }
    { id = "flint-careful"; name = "Flint 40B-A2.5B (careful: no thinking cap)"; contextWindow = 65536; maxTokens = 32768; }
    { id = "qwen"; name = "Qwen3.6-35B-A3B (2 slots x 32k)"; contextWindow = 32768; maxTokens = 16384; }
    { id = "qwen-27b"; name = "Qwen3.8-27B dense (slow, careful)"; contextWindow = 32768; maxTokens = 16384; }
    { id = "planner"; name = "planner (GLM-5.3 via OpenRouter, US hosts)"; contextWindow = 131072; maxTokens = 32768; }
  ];
  withReasoning = map (m: m // { reasoning = true; }) models;

  writable = name: file: ''
    run mkdir -p "$(dirname "$HOME/${name}")"
    run install -m 600 ${file} "$HOME/${name}"
  '';

  piSettings = (pkgs.formats.json { }).generate "pi-settings.json" {
    hideThinkingBlock = true; # Ctrl+T shows it
    showHardwareCursor = true; # Pi's drawn cursor looked squished
    editorPaddingX = 1;
  };
in
{
  imports = [ inputs.omp.homeManagerModules.default ];

  programs.omp = {
    enable = true;
    # Copied in as a writable file on each switch (omp rewrites it at runtime).
    settings = {
      # default/smol/task share one model so subagents don't make llama-swap reload;
      # slow reloads Flint without the thinking cap (~5 s swap); plan goes to the cloud.
      modelRoles = {
        default = "desktop/flint";
        smol = "desktop/flint";
        task = "desktop/flint";
        slow = "desktop/flint-careful";
        plan = "desktop/planner";
        tiny = "local/lfm2.5-230m"; # session titles on this machine's CPU
      };
      retry.fallbackChains.tiny = [ ];
      # Work-code lockdown: gateway models only, nothing sent to web-search providers.
      enabledModels = [ "desktop/*" "local/*" ];
      exa.enabled = false;
      tools.approval = {
        web_search = "deny";
        browser = "deny";
      };
      hideThinkingBlock = true;
      theme.dark = "titanium";
      composer.shape = "band";
      setupVersion = 2; # skip the first-run wizard
    };
  };

  home.file.".omp/agent/models.yml" = {
    force = true;
    source = (pkgs.formats.yaml { }).generate "omp-models.yml" {
      providers.desktop = {
        baseUrl = gateway;
        api = "openai-completions";
        auth = "none";
        models = withReasoning;
      };
    };
  };

  home.packages = [ agentPkgs.pi-coding-agent ];

  home.file.".pi/agent/models.json" = {
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

  # Pi writes lastChangelogVersion into its settings, so it needs a writable copy.
  home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (writable ".pi/agent/settings.json" piSettings);
}
