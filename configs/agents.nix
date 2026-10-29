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
    # Hosted models end with a price tag for the model picker: $ to $$$$ by blended cost per
    # 1M tokens (3 parts input to 1 output, since agent turns are mostly input): $ under $0.50,
    # $$ under $3, $$$ under $6, $$$$ above. Then input / output $ per 1M (OpenRouter, 2026-10-29).
    { id = "planner"; name = "planner: GLM-5.3, US hosts $ ($0.07 / $1.40)"; contextWindow = 131072; maxTokens = 32768; }
    # 1M on OpenRouter; told 400k so Pi compacts there, before long-context quality drops.
    { id = "cloud-deepseek"; name = "DeepSeek V4.1 Flash, US hosts $ ($0.05 / $0.50)"; contextWindow = 409600; maxTokens = 32768; }
    { id = "cloud-haiku"; name = "Claude Haiku 5.5 $ ($0.10 / $0.50)"; contextWindow = 409600; maxTokens = 65536; }
    # Frontier candidates for agent work in pis (nixos/dk.nix cloud-*): 1M+ context, told 400k
    # and 64k like DeepSeek, so Pi compacts before a run's history gets long and costly.
    { id = "cloud-deepseek-pro"; name = "DeepSeek V4 Pro $$ ($0.88 / $1.77)"; contextWindow = 409600; maxTokens = 65536; }
    { id = "cloud-grok"; name = "Grok 4.20 $$ ($1.25 / $2.50)"; contextWindow = 409600; maxTokens = 65536; }
    { id = "cloud-gemini-flash"; name = "Gemini 3.8 Flash $$ ($0.83 / $4.13)"; contextWindow = 409600; maxTokens = 65536; }
    { id = "cloud-gpt"; name = "GPT-6.1 Terra $$ ($1.00 / $5.00)"; contextWindow = 409600; maxTokens = 65536; }
    { id = "cloud-sonnet"; name = "Claude Sonnet 5.5 $$$ ($2 / $10)"; contextWindow = 409600; maxTokens = 65536; }
    { id = "cloud-opus"; name = "Claude Opus 5.5 $$$$ ($4 / $20)"; contextWindow = 409600; maxTokens = 65536; }
    # Worker candidate for pi-orch (`--model desktop/cloud-gptoss`); hosted only, too big for the GPU.
    { id = "cloud-gptoss"; name = "gpt-oss-120b, US hosts $ ($0.15 / $0.60)"; contextWindow = 131072; maxTokens = 16384; }
    # Research (ai-stack docs/models/sage-a1.5.md): Sage runs its own sub-agents, 2 slots
    # x 32k; the 4B runs 4 slots x 16k for quick lookups.
    { id = "sage"; name = "Sage-A1.5 35B-A3B (research, Q3, 2 slots x 32k)"; contextWindow = 32768; maxTokens = 16384; }
    { id = "agents-a1-4b"; name = "Agents-A1 4B (research, 4 slots x 16k)"; contextWindow = 16384; maxTokens = 8192; }
  ];
  withReasoning = map (m: m // { reasoning = true; }) models;

  # Agents with a free hand: Pi in a job folder under Anthropic's sandbox runtime (writes only
  # there, secrets unreadable, open web, logged), with guard.ts reviewing each command.
  sandboxRuntime = pkgs.callPackage ./sandbox-runtime { };
  piSandbox = pkgs.writeShellScriptBin "pi-sandbox" ''
    export PI_SANDBOX_SRT=${sandboxRuntime}/lib/node_modules/@anthropic-ai/sandbox-runtime/dist/index.js
    # srt on Linux runs bubblewrap (NixOS's setuid wrapper is already on PATH) and needs socat
    # to bridge the network proxy into the sandbox.
    export PATH=${lib.makeBinPath [ pkgs.socat pkgs.ripgrep ]}:$PATH
    exec ${pkgs.nodejs_22}/bin/node ${./pi-sandbox/pi-sandbox.mjs} "$@"
  '';
  # pis [JOB_DIR] [PI_ARGS...]: Pi in the sandbox, job folder defaulting to the current one.
  pis = pkgs.writeShellScriptBin "pis" ''
    job=.
    if [ $# -gt 0 ] && [ "''${1#-}" = "$1" ]; then job=$1; shift; fi
    exec ${piSandbox}/bin/pi-sandbox "$job" -- pi "$@"
  '';
  # Decomp toolkit (both machines, also inside pis): REA's CLI with wabt 1.0.42 and Ghidra
  # wired in, plus binaryen and wasm-tools, and nixpkgs' ps: REA checks its cleanup with ps,
  # and the macOS sandbox won't run /bin/ps, which is setuid. REA's own skill assumes its MCP
  # server; Pi has none, so ours says to call the same operations through the CLI. Upgrades:
  # the tool-watch skill.
  wabt = pkgs.callPackage ./rea/wabt.nix { };
  reaPkg = pkgs.callPackage ./rea { };
  rea = pkgs.writeShellScriptBin "rea" ''
    export REA_WABT_BIN_DIRECTORY=${wabt}/bin
    export GHIDRA_INSTALL_DIR=${pkgs.ghidra}/lib/ghidra
    export PATH=${lib.makeBinPath [ wabt pkgs.binaryen pkgs.wasm-tools pkgs.procps ]}:$PATH
    exec ${reaPkg}/bin/rea "$@"
  '';
  reaSkill = pkgs.runCommand "rea-skill" { } ''
    src=${reaPkg}/lib/node_modules/rea-agents/skills/reverse-engineer-anything
    mkdir -p $out
    cp -r $src/references $out/references
    # Keep REA's frontmatter (name, description), then our note, then its instructions.
    awk 'NR==1 || !done { print; if (NR > 1 && /^---$/) done = 1; next } { exit }' $src/SKILL.md > $out/SKILL.md
    cat ${./rea/pi-note.md} >> $out/SKILL.md
    awk 'f; /^---$/ && NR > 1 { f = 1 }' $src/SKILL.md >> $out/SKILL.md
  '';
  checkrefs = pkgs.writeShellScriptBin "checkrefs" ''exec ${pkgs.python3}/bin/python3 -I ${./pi-orch/checkrefs.py} "$@"'';

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
  # Workers get budget.ts's limits (wrap up at 60% context, stop at 85%, no sed-paging loops):
  # without them an orchestrated worker looped 91 turns until its 32k context ran out.
  subagentExtra = { worker = "max_tool_calls: 40\ntimeout: 15\n"; };
  subagentFiles = lib.mapAttrs'
    (name: model: lib.nameValuePair ".pi/agent/agents/${name}.md" {
      text = builtins.replaceStrings [ "\nmodel: claude-sonnet-4-5\n" "\nmodel: claude-haiku-4-5\n" ]
        [ "\nmodel: ${model}\n${subagentExtra.${name} or ""}" "\nmodel: ${model}\n${subagentExtra.${name} or ""}" ]
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
    [ "researcher" "researcher-fast" "architect" "reader" ])
  // lib.listToAttrs (map
    (name: lib.nameValuePair ".pi/agent/prompts/${name}.md" { source = ./pi-agents/${name}.md; })
    [ "research" "research-dig" "research-fast" "research-design-build" "lookup" "orchestrate" ])
  // {
    ".pi/agent/extensions/subagent/index.ts".source = "${subagentDir}/index.ts";
    ".pi/agent/extensions/subagent/agents.ts".source = "${subagentDir}/agents.ts";
    # Small-context helpers (pi-extensions): big tool output to files, and for research
    # sub-agents only, a tool budget plus the note and code_search tools.
    ".pi/agent/extensions/spill.ts".source = ./pi-extensions/spill.ts;
    # Output cut off at the token limit: continue with a nudge instead of ending the run.
    ".pi/agent/extensions/cutoff.ts".source = ./pi-extensions/cutoff.ts;
    # Write big files in parts (the bake-off's Rust runs all died on one huge write).
    # Every session: plan, tests first, check as you go (system-code). Local models also get
    # the output-limit rules (system-small); pis gives frontier models only system-code.
    ".pi/agent/APPEND_SYSTEM.md".text =
      builtins.readFile ./pi-agents/system-code.md + "\n" + builtins.readFile ./pi-agents/system-small.md;
    ".pi/agent/system-frontier.md".source = ./pi-agents/system-code.md;
    # Context and speed for small models (ai-stack docs/CODING-PLAN.md). Each has an off
    # switch, PI_<NAME>=0: EDITS, CHECK, BUDGET_TURN, MASK, THINKING, LOG_DIGEST (spill).
    ".pi/agent/extensions/edits.ts".source = ./pi-extensions/edits.ts; # edit, don't rewrite
    ".pi/agent/extensions/check.ts".source = ./pi-extensions/check.ts; # compile errors after edits
    ".pi/agent/extensions/budget-turn.ts".source = ./pi-extensions/budget-turn.ts; # reasoning budget per turn
    ".pi/agent/extensions/mask.ts".source = ./pi-extensions/mask.ts; # hide old tool output
    ".pi/agent/extensions/thinking.ts".source = ./pi-extensions/thinking.ts; # drop old reasoning past 50% context
    ".pi/agent/extensions/outline.ts".source = ./pi-extensions/outline.ts; # `outline` tool
    ".pi/agent/extensions/timings.ts".source = ./pi-extensions/timings.ts; # only with PI_TIMINGS_FILE
    # Hosted brain (cloud-*, planner): past a raw-read budget, big tool output is cut to its
    # head with a note to delegate to Flint workers (/orchestrate). PI_DELEGATE=0 turns it off.
    ".pi/agent/extensions/delegate.ts".source = ./pi-extensions/delegate.ts;
    # Memory across sessions (like Claude Code's): ~/.pi/memory, one file per fact + an index
    # in the system prompt; "remember ..." saves. Files stay on each machine. PI_MEMORY=0 off.
    ".pi/agent/extensions/memory.ts".source = ./pi-extensions/memory.ts;
    ".pi/agent/extensions/budget.ts".source = ./pi-extensions/budget.ts;
    # `reader` workers (PI_CLAIMS_FILE set): can't finish without a valid claims file, and
    # write nothing else. checkrefs checks their quotes (ai-stack docs/ORCHESTRATE-PLAN.md v2).
    ".pi/agent/extensions/claims.ts".source = ./pi-extensions/claims.ts;
    ".pi/agent/extensions/research.ts".source = ./pi-extensions/research.ts;
    # Auto-mode-style review of each command, only under pi-sandbox (PI_GUARD=1).
    ".pi/agent/extensions/guard.ts".source = ./pi-extensions/guard.ts;
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
  home.packages = [
    rea
    wabt
    pkgs.binaryen
    pkgs.wasm-tools
    pkgs.ghidra
    agentPkgs.pi-coding-agent
    checkrefs
    sandboxRuntime # srt
    piSandbox
    pis
    # Runs reader workers over a ledger's slices and checks their claims (ORCHESTRATE-PLAN.md v2).
    (pkgs.writeShellScriptBin "pi-orch" ''
      export PI_ORCH_CHECKREFS=${checkrefs}/bin/checkrefs
      exec ${pkgs.python3}/bin/python3 -I ${./pi-orch/orch.py} "$@"
    '')
  ];

  home.file = subagentFiles // {
    ".pi/agent/skills/rea".source = reaSkill;
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
