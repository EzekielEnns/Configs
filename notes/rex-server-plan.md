# Plan: Rex Linux server on the NixOS desktop

Goal: Rex sessions that live on the desktop (`#desktop`), opened from Rex for Mac, so long
Pi jobs, evals and desktop rebuilds keep running while the Mac sleeps, and Claude Code can
drive them with `rex -S desktop …` instead of ssh panes.

Status (2026-10-29): researched, not installed. Earliest install under the 14-day release
rule: about 2026-11-04 (Linux previews so far: preview.4 on 10-21 to preview.10 on 10-28).

## What we get

- Desktop tabs in the Mac app, running natively there (no ssh layer). They survive the Mac
  sleeping, disconnecting or restarting, and (login-server mode) Rex upgrades and rebuilds.
- Long jobs (`pis`, evals, `/orchestrate`) and desktop rebuild panes live on the desktop.
- Rex's `xterm-rex` terminfo installed properly on the desktop (the earlier lag was a
  missing terminfo).
- Not yet in Rex: clicking file links printed by remote programs, pasting images into a
  remote session. The `nvim-open://` handler covers file links (see below).

## Design

- **Package:** Rex's official flake, `https://pkgs.superlogical.com/rex/nix/preview.tar.gz`,
  with its NixOS module. `flake.lock` pins the release. Downloads need the beta package
  token in `/etc/nix/netrc` (root, 0600), placed by hand: never in git or the Nix store.
- **Mode:** login server. It runs as root and hands each connection to a server running as
  the caller's own account, so programs run as `ezekiel` with the usual Nix, sudo and `pis`.
  Not the shared server (a `rex` system account; upgrades end sessions).
- **Network:** the system Tailscale with Tailscale Serve, HTTPS on port 7297, tailnet only.
  Otherwise Rex listens only on Unix sockets under `/run/rex`: nothing on the LAN, no
  firewall change. Not Rex's built-in Tailscale (it would add a second device).
- **Auth:** callers are let in by their Tailscale login. Rex has no keys or passwords yet,
  so anything on the tailnet signed in as the user gets a full shell as `ezekiel`.

## Sandbox first (must land before the server)

`pis` lets agents reach the host `desktop` by name for the model gateway, on any port. With
Rex on desktop:7297, a sandboxed agent could open a desktop shell outside the sandbox, and
Rex would see the connection as the user (the Mac's tailnet login).

- Narrow `GATEWAY` in `configs/pi-sandbox/pi-sandbox.mjs` to ports: `desktop:4000`
  (gateway) and `desktop:8090` (evidence service). srt supports a `:port` suffix on
  `allowedDomains` entries.
- Add `desktop:7297` and the full `*.ts.net` name to `deniedDomains`, with a
  `deniedDomainReasons` entry.
- Check from inside `pis`: the gateway, the evidence service, and a refused connection to
  the Rex port (by short name, by full tailnet name, and by Tailscale IP).
- Already fine: the Mac's own Rex socket is unreachable from `pis` (checked 2026-10-29:
  "Operation not permitted").

## Steps

1. **You:** turn on HTTPS certificates for the tailnet in the Tailscale admin console.
2. **You:** place the beta token in `/etc/nix/netrc` on the desktop. Then check whether the
   Mac needs it too (`nix flake update` / lock checks may fetch the input there).
3. The sandbox change above, committed and checked from inside `pis`.
4. `flake.nix`: add the `rex` input; add `rex.nixosModules.default` and
   `./modules/rex-server.nix` to the desktop host only.
5. `modules/rex-server.nix` (desktop only):

   ```nix
   { ... }: {
     # Rex Linux server (beta): sessions live on this box, reached from Rex for Mac over
     # Tailscale Serve (HTTPS :7297, tailnet only). Login-server mode: programs run as the
     # caller's own account, and sessions survive Rex upgrades and nixos-rebuild.
     # Download token: /etc/nix/netrc (root 0600), placed by hand, never in git.
     services.rex.loginServer = {
       enable = true;
       # The Tailscale login, read from an untracked file if it's an email address.
       accounts.ezekiel.principals = [ "tailscale:<tailscale-login>" ];
       tailscaleServe.enable = true;
     };
   }
   ```

6. Rebuild the desktop. This first one still runs in a Mac pane over ssh.
7. Mac: Rex → **Add Remote Host…** → the desktop's tailnet HTTPS name. Use the app, not
   `rex hosts add`: hosts added from the CLI don't show in the sidebar yet.
8. Check: open a desktop tab; close the Mac lid and reopen it; the session is still there;
   `rex -S desktop session list` works from the Mac; a bell or notification from a
   desktop tab reaches the Mac.

## What changes after

- **Desktop rebuilds:** in a desktop session tab (`rex -S desktop split … -- sudo
  nixos-rebuild …`, read back with `rex -S desktop capture`). Mac rebuilds keep the stacked
  pane rule.
- **`nvim-open://` handler:** for `host=desktop` links, look for a desktop block running nvim
  through `rex -S desktop`, jump to the line through its server socket over ssh, else open
  a split in a desktop session; `ssh -t desktop nvim +L FILE` stays the fallback when Rex
  isn't reachable. Desktop files open in a desktop tab, not the Mac tab you're in.
- **Updates:** `nix flake update rex` and a rebuild, at least 14 days after a release.
  Tracking it in tool-watch is harder because of the token-gated download.

## Open questions

- The token on the Mac: needed or not (step 2).
- Beta rough edges people report: a tab hangs after the remote host powers off; a delay
  switching tabs on a remote host; "Connecting…" hangs with plain-HTTP tailnet listeners
  (HTTPS through Serve avoids that).
