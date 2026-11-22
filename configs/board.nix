{ config, ... }:
# s-chan's agent board, on trial. Uses the binary built in the s-chan checkout
# (cargo build --release there), so a rebuild of s-chan applies without a switch;
# restart the two agents after rebuilding it:
#   launchctl kickstart -k gui/$UID/org.nix-community.home.board-serve (and board-wake)
# To stop the trial, drop this file's import from darwin/home.nix and switch.
let
  repo = "${config.home.homeDirectory}/Documents/repos/s-chan";
  bin = "${repo}/target/release";
  board = "${bin}/board";
  log = "${config.home.homeDirectory}/Library/Logs/board.log";
  hook = event: [
    {
      hooks = [
        {
          type = "command";
          command = "${board} hook ${event} --harness claude";
          timeout = 5;
        }
      ];
    }
  ];
in
{
  config = {
    # Agents run `board ...` from Bash.
    home.sessionPath = [ bin ];

    programs.claude-code.settings = {
      # The wake agent writes one line into an idle session's inbox. Without this,
      # Claude Code may hold those lines for approval. It applies to every sender,
      # including other sessions' SendMessage, not just the board.
      crossSessionInbound = "accept";
      # Registers the session (prints nothing); marks busy and prints new tags
      # (≤3 lines, nothing when empty); marks idle. These lists add to claude.nix's.
      hooks.SessionStart = hook "start";
      hooks.UserPromptSubmit = hook "prompt";
      hooks.Stop = hook "stop";
    };

    # The 8 commands and the rules, loaded on demand. Linked to the checkout so
    # edits there apply at once.
    home.file.".claude/skills/board".source = config.lib.file.mkOutOfStoreSymlink "${repo}/skills/board";

    launchd.agents.board-serve = {
      enable = true;
      config = {
        ProgramArguments = [ board "serve" ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        StandardOutPath = log;
        StandardErrorPath = log;
      };
    };

    launchd.agents.board-wake = {
      enable = true;
      config = {
        # Add "--dry-run" to log who would be woken without waking anyone.
        ProgramArguments = [ board "wake" ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        StandardOutPath = log;
        StandardErrorPath = log;
      };
    };
  };
}
