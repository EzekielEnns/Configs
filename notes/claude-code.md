## settings.json is read-only (home-manager)

~/.claude/settings.json is a symlink into /nix/store, managed by configs/claude.nix.
anything in claude code that tries to save a setting fails with:

    Autocompact unchanged · Couldn't save setting: Failed to read raw settings from
    /Users/ezekiel/.claude/settings.json: Error: EACCES: permission denied, open
    '/nix/store/...-home-manager-files/.claude/settings.json.tmp.<pid>.<hash>'

same thing for `/model` ("couldn't save it as your default"), `/config`, `/theme`, `/autocompact`.
the change still applies for the current session, it just doesn't persist.

this is expected, not a bug. to make a change stick:

1. edit `settings` in configs/claude.nix (top-level keys directly, env vars under `env = { ... }`)
2. `darwin-rebuild switch --flake .#macbook`
3. restart claude code

## things set in configs/claude.nix

- `autoCompactWindow = 400000` (top-level key) — compact at ~400K tokens (default ~967K on 1M).
  plain integer, range 100000-1000000. a per-model value saved by `/autocompact` (modelSettings) would
  override it, but that can't be written here anyway.
  the env var `CLAUDE_CODE_AUTO_COMPACT_WINDOW` does the same, but "400k" there is read as 400 and clamped to 100K.
- `env.CLAUDE_CODE_SUBAGENT_MODEL = "sonnet"` — subagents default to sonnet instead of inheriting opus.
  agent frontmatter `model:` still wins. built-in Explore/Plan are not covered unless
  `CLAUDE_CODE_SUBAGENT_MODEL_FORCE = "1"` is also set.

## other cost levers (not set)

- `effortLevel` low|medium|high|xhigh (set at session start, changing mid-session can bust the cache)
- `model = "opusplan"` opus for plan mode, sonnet for execution
- `MAX_THINKING_TOKENS` / `alwaysThinkingEnabled = false`
- `promptCacheTtl` / `subagentPromptCacheTtl` "5m" | "1h"
- do NOT set DISABLE_PROMPT_CACHING, it raises cost

docs: https://code.claude.com/docs/en/env-vars.md and https://code.claude.com/docs/en/model-config.md
