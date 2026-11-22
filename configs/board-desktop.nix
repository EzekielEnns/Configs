# The desktop runs the board's primary node: it owns board.db and accepts the
# MacBook's node over the tailnet (token in ~/.board/token, never in this repo).
# No Claude hooks here (no Claude Code config on this host); pi joins in n4.
{ ... }:
let
  checkout = "/home/ezekiel/Documents/repos/s-chan";
in
{
  imports = [ (builtins.getFlake "git+file://${checkout}").homeModules.default ];

  services.board = {
    enable = true;
    host = "desktop";
    listen = "tailscale:7300";
    claude = false;
  };
}
