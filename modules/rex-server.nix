{ lib, ... }:
# Rex Linux server (beta): sessions live on this box, reached from Rex for Mac over Tailscale
# Serve (HTTPS :7297, tailnet only; nothing on the LAN). Login-server mode: a root process maps
# each caller to an account and runs a server per account as that account, so programs run as
# ezekiel with the usual Nix, sudo and pis, and sessions survive Rex upgrades and nixos-rebuild.
#
# Imported by flake.nix only when the `rex` input is present (see the commented input there and
# notes/rex-server-plan.md). Untracked, placed by hand on the desktop:
#   /etc/nix/netrc       the beta package token (root 0600), for the token-gated flake
#   /etc/rex/principal   who may connect, e.g. tailscale:<login>; kept out of this public repo
# Builds read the principal at eval time, which the desktop's --impure rebuild allows.
let
  principalFile = /etc/rex/principal;
in
{
  assertions = [
    {
      assertion = builtins.pathExists principalFile;
      message = "rex-server: write the Tailscale principal (tailscale:<login>) to ${toString principalFile} first.";
    }
  ];

  services.rex.loginServer = {
    enable = true;
    accounts.ezekiel.principals =
      lib.optional (builtins.pathExists principalFile) (lib.strings.trim (builtins.readFile principalFile));
    tailscaleServe.enable = true;
  };
}
