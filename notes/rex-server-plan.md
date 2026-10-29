# Plan: Rex Linux server on the NixOS desktop

Goal: Rex sessions that live on the desktop (`#desktop`), opened from Rex for Mac, so long
Pi jobs, evals and desktop rebuilds keep running while the Mac sleeps, and Claude Code can
drive them with `rex -S desktop …` instead of ssh panes.

Status (2026-10-29): prepared and off; sandbox narrowed. Not installed. Earliest install under the 14-day release
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

## Sandbox (done, e8b1b1c)

`pis` reaches the desktop only on the gateway's ports: `desktop:4000` (LiteLLM: models, Jev)
and `desktop:8090` (evidence), by name or by its Tailscale IP. Private, Tailscale (100.64/10)
and ULA addresses are refused by name or literal, and `*:7297` (Rex's server) is denied with a
reason. Checked from inside the sandbox (2026-10-29): gateway and evidence answer; desktop:22
and :7297 refused by short name, MagicDNS name and Tailscale IP; LAN addresses refused; public
hosts allowed. The Mac's own Rex socket was already unreachable ("Operation not permitted").
Other services on the desktop (notes sync, anything later) are unreachable from `pis` by
default; add a port to `GATEWAY_PORTS` in `configs/pi-sandbox/pi-sandbox.mjs` only on purpose.

## Prepared (off until the switch)

- `modules/rex-server.nix`: the login server for `ezekiel` over Tailscale Serve. The
  principal is read from `/etc/rex/principal` (untracked); the build stops with a clear
  message if it's missing.
- `flake.nix`: the desktop host imports `rex.nixosModules.default` and the module above only
  when the `rex` input exists (`inputs ? rex`). The input is a commented line, so nothing
  token-gated is fetched until then.
- **The switch:** uncomment `rex.url = …preview.tar.gz` in `flake.nix`'s inputs.

## Steps left

On the Tailscale admin console:
1. Turn on HTTPS certificates for the tailnet (DNS page → HTTPS Certificates).

On the desktop (`ssh desktop`):
2. The beta token, root-only, never in git:
   `sudo install -m 600 /dev/stdin /etc/nix/netrc <<< "machine pkgs.superlogical.com login rex password <TOKEN>"`
3. Who may connect, from `tailscale whois $(tailscale ip -4 <mac>)` or the admin console's
   user name: `sudo install -D -m 644 /dev/stdin /etc/rex/principal <<< "tailscale:<login>"`

In this repo (14-day rule waived for this beta):
4. Uncomment the `rex.url` line in `flake.nix`.
5. Lock it on the desktop (the token lives there): sync the branch to the desktop, then
   `cd ~/Documents/repos/configs && nix flake lock --update-input rex`; bring `flake.lock`
   back to the Mac with the commit (`git commit flake.nix flake.lock`).
6. Rebuild the desktop (this one still runs in a Mac pane over ssh):
   `sudo nixos-rebuild --flake .#desktop switch --impure`.
7. Check on the desktop: `systemctl status rex-login-server`, `tailscale serve status` shows
   :7297, `ls /run/rex/login-server.sock`.
8. Mac: Rex → **Add Remote Host…** → `https://desktop.<tailnet>.ts.net` (use the app; hosts
   added with `rex hosts add` don't show in the sidebar yet).
9. Check: open a desktop tab; close the lid and reopen; the session is still there;
   `rex -S desktop session list` from the Mac; a bell from a desktop tab reaches the Mac;
   `pis` still can't reach :7297.

The Mac doesn't need the token to build (checked 2026-10-29, Nix 2.31.5): with a `rex` entry in
`flake.lock`, the darwin config evaluates without fetching it. Locking or updating `rex` does
fetch, so run `nix flake lock --update-input rex` (and any whole-flake `nix flake update`) on
the desktop, or name the inputs to update on the Mac (`nix flake update nixpkgs …`).
`nix flake metadata`/`check` on the Mac would also fail on the token.

Channel: preview (both preview and snapshot exist for this wave; preview is the tagged one).
The 14-day rule is waived for Rex's beta (user, 2026-10-29).

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
