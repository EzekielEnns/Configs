{ pkgs, ... }:
let
  # Shared by the setting and the status line so the denominator can't drift.
  autoCompactWindow = 400000;

  # Records which conversation runs in which Rex pane. SessionStart also fires
  # on /clear and /resume, so the file always holds the current session id.
  rexPaneHook = pkgs.writeShellScript "claude-rex-pane" ''
    [ -n "''${REX_BLOCK:-}" ] || exit 0
    dir="$HOME/.local/state/rex-resurrect/claude"
    mkdir -p "$dir"
    ${pkgs.jq}/bin/jq -r '.session_id // empty' \
      > "$dir/$(printf %s "$REX_BLOCK" | tr -c 'A-Za-z0-9-' _)"
  '';

  # In Rex, tells Claude how to write code locations so a click opens them in Neovim
  # in this tab (configs/nvim-open). SessionStart output becomes context; outside Rex
  # it prints nothing.
  nvimLinksHook = pkgs.writeShellScript "claude-nvim-links" ''
    [ -n "''${REX_BLOCK:-}" ] || exit 0
    enc() { ${pkgs.jq}/bin/jq -rn --arg s "$1" '$s | @uri'; }
    base="nvim-open://open?host=$(hostname -s)&session=$(enc "''${REX_SESSION:-}")&block=$(enc "$REX_BLOCK")"
    cat <<EOF
    Code links: this terminal opens nvim-open:// links in the user's Neovim. When you point at a specific line of a file, write it as a markdown link with the path and line as its text and this target, adding the line and the absolute path (spaces as %20):
    [src/app.ts:42]($base&line=42&file=/abs/path/src/app.ts)
    Plain paths are fine for whole files or long lists of files.
    EOF
  '';

  # Reads the session JSON on stdin. rate_limits only exists for Pro/Max
  # subscribers and only after the first API response, hence the `// empty`s.
  statusLine = pkgs.writeShellScript "claude-statusline" ''
    input=$(${pkgs.coreutils}/bin/cat)
    jq=${pkgs.jq}/bin/jq

    # Context in tokens against the auto-compact threshold (not the full window),
    # e.g. "130k/400k". Used tokens are derived from the window percentage.
    ctx=$(echo "$input" | $jq -r '
      (.context_window.used_percentage // empty) as $p
      | (.context_window.context_window_size // 0) as $win
      | ${toString autoCompactWindow} as $cap
      | def k: if . >= 1000000 then "\(. / 1000000 | floor)M" else "\(. / 1000 | floor)k" end;
        "\($win * $p / 100 | k)/\(([$win, $cap] | min) | k)"')
    week=$(echo "$input" | $jq -r '.rate_limits.seven_day.used_percentage // empty')

    out="ctx ''${ctx:-0}"
    [ -n "$week" ] && out="$out | 7d $(printf '%.0f' "$week")%"
    echo "$out"
  '';
in
{
  config = {
    # ~/.claude/settings.json becomes a read-only store symlink, so this file is
    # the only place it changes: `/config`, `/theme` and `/model`'s "save as
    # default" can no longer write it. Edit here and rebuild instead.
    #
    # Claude Code still writes plenty of *other* things under ~/.claude
    # (history, sessions, projects, paste-cache) — only settings.json is owned.
    programs.claude-code = {
      enable = true;
      # claude is installed by its own native installer into ~/.local/bin;
      # null keeps home-manager from putting a second copy on PATH.
      package = null;

      settings = {
        model = "opus[1m]";
        tui = "fullscreen";
        editorMode = "vim";
        permissions.defaultMode = "auto";
        # The notes vault (configs/notes): its tools only. notes_write asks with its own
        # dialog (MCP elicitation), so no permission prompt on top; direct edits are denied.
        # The read-only graph-* Spanner servers from anti-evil's .mcp.json: local and dev
        # without asking, every prod call asks.
        permissions.allow = [
          "mcp__notes__notes_search"
          "mcp__notes__notes_read"
          "mcp__notes__notes_recent"
          "mcp__notes__notes_write"
          "mcp__graph-local"
          "mcp__graph-dev"
        ];
        permissions.ask = [ "mcp__graph-prod" ];
        permissions.deny = [ "Edit(~/Notes/**)" "Write(~/Notes/**)" ];

        # Compact at ~400K tokens instead of the ~967K default on a 1M window.
        # Plain integer; a per-model value saved by /autocompact would override it.
        inherit autoCompactWindow;

        statusLine = {
          type = "command";
          command = "${statusLine}";
        };

        # Compacts long conversations while idle, before the prompt cache expires.
        idleCompaction = true;

        env = {
          # Subagents without their own `model:` run on Sonnet instead of
          # inheriting Opus. Agent frontmatter still wins; built-in Explore/Plan
          # are unaffected (add CLAUDE_CODE_SUBAGENT_MODEL_FORCE = "1" to cover them).
          CLAUDE_CODE_SUBAGENT_MODEL = "sonnet";
          # Claude Code doesn't detect Rex as a terminal with clickable links, so
          # markdown links printed as "text (url)". This makes them real links,
          # which nvim-open:// needs (configs/nvim-open).
          FORCE_HYPERLINK = "1";
        };

        # Emit an OSC 777 desktop notification, which ghostty turns into a real
        # macOS banner carrying Claude's message. Requires `allow-passthrough on`
        # in tmux (configs/tmux.nix) or tmux swallows the sequence.
        # The alternative, "terminal_bell", flags the tmux window red instead but
        # produces no banner: on macOS ghostty's `system` bell feature is only
        # the alert sound. Claude picks one channel, so it is one or the other.
        preferredNotifChannel = "ghostty";

        # What `rex skill setup` would add here if this file were writable:
        # tells each session it's running in Rex, and which session/terminal.
        hooks.SessionStart = [
          {
            hooks = [
              {
                type = "command";
                command = "/bin/sh -c 'rex __internal session-start --agent claude 2>/dev/null || true'";
                timeout = 5;
              }
              {
                # Lets configs/rex-resurrect.lua bring this pane back with
                # `claude --resume <id>` after a Rex server restart.
                type = "command";
                command = "${rexPaneHook}";
                timeout = 5;
              }
              {
                type = "command";
                command = "${nvimLinksHook}";
                timeout = 5;
              }
            ];
          }
        ];

        voice = {
          enabled = false;
          mode = "tap";
        };
        voiceEnabled = false;
        agentPushNotifEnabled = true;

        # Replaces the "Generated with Claude Code" footer (and its link back to the
        # session) on PRs and comments, and the Co-Authored-By trailer on commits.
        attribution = {
          pr = "— Claudy McClaudin helped";
          commit = "Claudy McClaudin helped";
        };

        # "I have seen this dialog" flags — pinned so they stay dismissed.
        skipAutoPermissionPrompt = true;
        skipWorkflowUsageWarning = true;
      };
    };

    # User-scope MCP servers, for every project. They live in ~/.claude.json, which Claude
    # Code rewrites, so each is added there once rather than owned.
    # The remote ones are the providers' own servers, signed in once with /mcp (OAuth), so
    # they keep working when the claude.ai connector proxy doesn't. Slack isn't here: its
    # server only takes pre-registered apps, so it stays a claude.ai connector.
    home.activation.claudeMcp = ''
      claude="$HOME/.local/bin/claude"
      if [ -x "$claude" ]; then
        if ! "$claude" mcp get notes >/dev/null 2>&1; then
          run "$claude" mcp add -s user notes -- /etc/profiles/per-user/$USER/bin/notes-mcp || true
        fi
        for server in \
          linear=https://mcp.linear.app/mcp \
          notion=https://mcp.notion.com/mcp \
          granola=https://mcp.granola.ai/mcp \
          figma=https://mcp.figma.com/mcp \
          icepanel=https://mcp.icepanel.io/mcp; do
          name="''${server%%=*}"
          if ! "$claude" mcp get "$name" >/dev/null 2>&1; then
            run "$claude" mcp add -s user --transport http "$name" "''${server#*=}" || true
          fi
        done
      fi
    '';

    # The module doesn't set force, and a real settings.json already exists on
    # this machine; without this, activation refuses to clobber it.
    home.file.".claude/settings.json".force = true;

    # Stub from `rex skill setup`; the real guide comes from the installed rex.
    home.file.".claude/skills/rex/SKILL.md".text = ''
      ---
      name: rex
      description: Use the rex CLI to manage Rex sessions, open tabs, arrange panes, run commands, inspect terminal output, and control connected Rex apps.
      metadata:
        rex-stub: "2"
      ---
      <!-- Installed by "rex skill setup". Remove it with "rex skill remove". -->

      Run `rex __internal skill` and follow the guide it prints. The guide comes from
      the installed Rex CLI, so it describes the commands available in that version.

      If the command fails, the installed Rex version predates the guide. Start with
      `rex whoami --json`, then use `rex --help` and `rex COMMAND --help`.
    '';

    # Rebuild this flake from an agent: runs in a Rex pane below so the user approves sudo
    # (Touch ID) themselves, then the agent reads the result.
    home.file.".claude/skills/configs-rebuild/SKILL.md".text = ''
      ---
      name: configs-rebuild
      description: Rebuild and switch Zeek's MacBook Nix config (~/Documents/repos/Configs, nix-darwin) in a Rex pane below the agent, where Zeek approves sudo with Touch ID, then report the result. Use after changing anything in the Configs repo, or when asked to "rebuild", "apply the config", "darwin-rebuild" or "switch".
      ---

      # Configs rebuild

      The rebuild needs sudo, and that approval is Zeek's: always run it in a visible Rex
      pane, never in the agent's own shell, and never try to get around the prompt.

      1. Check first. In ~/Documents/repos/Configs, run `git status --short` and tell Zeek
         in one line what will be applied, including uncommitted changes that aren't
         yours (the switch applies the whole working tree).
      2. Start it in a pane below:

         ```sh
         rex split -s "$REX_SESSION" -b "$REX_BLOCK" --split=below --ratio 40 --keep-open \
           -c ~/Documents/repos/Configs -- sudo darwin-rebuild switch --flake .#macbook --impure
         ```

         `--impure` lets it load private repos cloned next to Configs (s-chan),
         as the desktop rebuild does. It prints the new block's ID. Tell Zeek: "rebuild running below; touch the
         sensor when sudo asks."
      3. Wait for it: `rex wait -s "$REX_SESSION" BLOCK --for 20m` returns the rebuild's exit
         status (it can take minutes, so run it in the background or with a long timeout). Then read the end with
         `rex capture -s "$REX_SESSION" -b BLOCK | tail -40`.
      4. Report: success or the actual error lines. On an evaluation error, fix it and go
         back to step 2. Don't retry a failure blindly.
      5. Say what needs a restart, based on what changed: `/mcp` and reconnect for MCP
         servers (e.g. the notes tools), a new shell for zsh or Starship, and restarting
         Claude Code for settings or skills.
      6. Close the pane with `rex block close -s "$REX_SESSION" BLOCK` once Zeek has seen
         the result, unless they want it kept.

      For the NixOS desktop, use the desktop-rebuild skill instead.
    '';

    # Same idea for the NixOS desktop, through its Rex server (modules/rex-server.nix) so there's
    # no Tailscale SSH login check; SSH is only the fallback.
    home.file.".claude/skills/desktop-rebuild/SKILL.md".text = ''
      ---
      name: desktop-rebuild
      description: Rebuild and switch Zeek's NixOS desktop (host "desktop" on Tailscale, flake .#desktop) from the MacBook, through the desktop's Rex server (no SSH login), in a "rebuild" Rex session where Zeek types the sudo password, then report the result. Use when asked to rebuild/apply/switch the desktop, or after a Configs change that touches nixos/ or anything the desktop host imports.
      ---

      # Desktop rebuild

      The desktop has its own checkout, `~/Documents/repos/configs` (lowercase), which is
      separate from the MacBook's `~/Documents/repos/Configs`. It rebuilds from its own
      working tree, so changes made on the MacBook aren't there until they're pushed and pulled.
      Its weekly auto-upgrade (Sun 20:00, nixos/dk.nix) builds from that same path.

      Reach it through its Rex login server, which runs as ezekiel and needs no SSH login.
      The CLI needs the full tailnet name and port:

      ```sh
      D="$(tailscale status --json | python3 -c 'import json,sys;print([p["DNSName"] for p in json.load(sys.stdin)["Peer"].values() if p["HostName"]=="nixos"][0].rstrip("."))'):7297"
      rex -S "$D" ls    # should list sessions
      ```

      Plain `rex -S desktop` fails, because the TLS certificate is for the full name.
      Run every desktop command as `rex -S "$D" run -s rebuild ...` in a session named
      `rebuild`. Create it once with `rex -S "$D" new rebuild` if `ls` doesn't show it.

      1. Compare the two checkouts:

         ```sh
         rex -S "$D" run -s rebuild --keep-open --wait -c /home/ezekiel/Documents/repos/configs -- \
           sh -c 'git fetch -q; git status -sb; git log --oneline -1'
         ```

         It prints the block ID. Read that block with `rex -S "$D" capture -s rebuild -b BLOCK`,
         then close it. Do the same `git status -sb` and `git log --oneline -1` locally in
         ~/Documents/repos/Configs.
         Tell Zeek in a line or two: which commit each side is on, uncommitted changes on
         either side, and whether the change they want is actually on the desktop yet.
      2. If it isn't, ask Zeek how to get it there. Never commit, push, pull, stash or
         reset on either machine without being asked. The usual way: commit and push on the
         MacBook, then `git pull --ff-only` on the desktop. Uncommitted edits on the desktop
         (often nixos/dk.nix) are Zeek's; leave them alone.
      3. Start the rebuild with `scripts/desktop-rebuild.sh` from the desktop's checkout, in a
         local pane below so Zeek sees it. The pane connects by SSH because a desktop session
         can't be shown inside a local pane. It asks for the desktop's sudo password (there's
         no Touch ID there), then runs nixos-rebuild as its own systemd job and follows that
         job's log.
         - Why a separate job: a rebuild that updates Rex restarts the Rex server, which would
           kill a rebuild running inside a Rex session halfway through the switch.
         - Why it sets a throwaway git config: root builds ezekiel-owned repos (configs, and
           ai-stack and evidence through getFlake). git refuses another user's repo, and Nix
           ignores GIT_CONFIG_* variables. nixos/dk.nix also allows these repos for good.

         ```sh
         rex split -s "$REX_SESSION" -b "$REX_BLOCK" --split=below --ratio 45 --keep-open -- \
           ssh -t desktop 'sh ~/Documents/repos/configs/scripts/desktop-rebuild.sh'
         ```

         Tell Zeek: "desktop rebuild below: touch the sensor on the Mac (Secretive), or type the desktop password."
      4. Wait: `rex wait -s "$REX_SESSION" BLOCK --for 60m` (in the background), then read
         `rex capture -s "$REX_SESSION" -b BLOCK | tail -20`. The script ends with
         `== RESULT: success ==` or the failure.
      5. On failure, find the cause before trying again:
         - `journalctl -u nixos-rebuild-switch-to-configuration` shows what the switch did.
         - `systemctl --failed` shows which services failed.
         - Exit 4 means the system switched but a service failed.
         - home-manager-ezekiel failing with 127 means an activation script ran a command
           that isn't on its small PATH.
         Read these through the `rex -S "$D" run --wait` pattern. Report the actual error
         lines. Name what needs restarting. Don't reboot unless Zeek asks.
      6. Close the pane with `rex block close -s "$REX_SESSION" BLOCK` once Zeek has seen the result.

      If nothing reaches the desktop, check `tailscale status` first. If it's expired, Zeek
      runs `tailscale up` on the MacBook. Tailscale SSH may also ask Zeek for a browser check.
    '';

    # Phased builds reviewed in Neovim: one phase at a time, uncommitted, in a rex
    # pane below the agent.
    home.file.".claude/skills/phase-review/SKILL.md".text = ''
      ---
      name: phase-review
      description: Build a planned change in phases and stop after each one for the user to review the uncommitted diff in Neovim, in a Rex pane below the agent. Use when the user asks to work in phases, to review each phase or step before it is committed, to "bring up the diff", or for "the review setup with rex".
      ---

      # Phase review

      The user reads every phase in Neovim before it is committed. Nothing is committed,
      pushed or started early.

      ## Before the first phase

      - Agree the phases with the user: a short table of what each one holds and what ends
        it. Put the same table on the ticket if there is one.
      - Work in the primary checkout on the ticket's branch. No worktrees.
      - Keep a phase small enough to read in one sitting, and never mix two purposes in one.

      ## Each phase

      1. Build the phase. Leave every change uncommitted.
      2. Run the repo's full check (`make check`, `pnpm check`, ...) and fix what it finds.
         Say plainly what passed and what was not run.
      3. Open the diff in a pane below your own, from the repo's root:

         ```sh
         rex split -s "$REX_SESSION" -b "$REX_BLOCK" --split=below --ratio 65 \
           -c "$PWD" -- nvim -c "DiffviewOpen"
         ```

         `DiffviewOpen` with no argument shows the working tree against HEAD, untracked
         files included, which is exactly the phase. To show a whole branch after its
         phases are committed, use `nvim -c "DiffviewOpen main...HEAD"`.
         Confirm it opened with `rex capture -s "$REX_SESSION" -b BLOCK --trim | head`.
      4. Stop and tell the user, in this order:
         - that the phase is uncommitted and where the diff is open;
         - the files to read, in reading order, one line each on what changed;
         - anything that differs from the agreed plan, and why;
         - what to look at closely (behaviour changes, risks, things left out).
      5. Wait. On changes, edit, rerun the check, and say what moved; the open Neovim
         reloads the files. On "commit", commit that phase alone, then start the next one.

      ## Rules

      - One commit per phase, made only after the user says so. Never amend an earlier
        phase's commit; a fix found later is its own commit.
      - Never push, open a pull request or deploy as part of a phase. Ask first.
      - A migration is generated by the repo's own command and is not applied to a shared
        or local database just to test the phase, unless the user asks.
      - Leave panes the user opened alone. Open one new pane per review; the user closes it.
      - If a phase turns up something the plan missed, say so at the stop, with a
        recommendation, and do not build it into the phase unasked.
    '';

    # poi (configs/poi): Jev-ranked points of interest in a code base or a diff.
    home.file.".claude/skills/poi/SKILL.md".text = ''
      ---
      name: poi
      description: Rank where in a code base (or a diff) something is handled, configured or decided, as path:line hits, with the `poi` CLI. Use when finding your way in unfamiliar code ("where is X configured", "what handles Y"), reviewing a diff or PR, or tracing how data flows through calls.
      ---

      # poi

      `poi` asks Jev (a small decision model behind the desktop gateway; it keeps no data) to
      rank a repo's files, then their functions, against a question. One call takes seconds and
      costs a fraction of a cent. Use it to pick what to read, then Read just those lines.
      Plain grep is still better for an exact string you already know.

      Run it with Bash, always with `--json --no-links` (one compact line; paths relative to
      `root`):

      ```sh
      poi --json --no-links "where is compaction configured" .        # code under paths (default .)
      poi --json --no-links -n 10 "what handles retries" src lib      # fewer hits, given folders
      poi --json --no-links --follow "where is the token checked" .   # + each hit's callers
      poi --json --no-links --flow --diff main...HEAD "auth changes"  # a diff, in call order
      ```

      Each hit has `file`, `line`, `symbol`, `score` (0-4) and a preview. Scores bunch near the
      top, so read the top few rather than trusting the order further down. Over about 600
      blocks it stops and asks for `--yes`; narrow the paths instead. Never `--tour` (it
      occupies the desktop's local model).
    '';
  };
}
