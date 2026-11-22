# s-chan's agent board, on trial. Everything lives in s-chan's own home module
# (s-chan/nix/home.nix): the `board node` service, the Claude hooks, the skill.
# It's a private repo cloned next to this one, loaded like atlas and ai-stack,
# so rebuilds need --impure. Updating s-chan = rebuild this.
# To stop the trial, drop this file's import from darwin/home.nix and switch.
{ ... }:
let
  checkout = "/Users/ezekiel/Documents/repos/s-chan";
in
{
  imports = [ (builtins.getFlake "git+file://${checkout}").homeModules.default ];

  services.board = {
    enable = true;
    # Skill edits in the checkout apply at once.
    inherit checkout;
    host = "mac";
    # The desktop's node owns the board (configs/board-desktop.nix); this one forwards.
    upstream = "desktop:7300";
  };
}
