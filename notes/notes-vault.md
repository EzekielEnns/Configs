# The shared notes vault

`~/Notes` on the Mac and the desktop, and the same folder in Obsidian on both phones, synced
with Syncthing over Tailscale. Agents (Pi, pis, Claude Code) read it and write it only with a
yes. Built 2026-10-29.

## Layout

| Folder | For | Agents |
|---|---|---|
| `Inbox/` | quick captures, `:Notes new` | write with approval |
| `Shared/` | the household's lists and plans | write with approval |
| `Daily/` | one note a day, `:Notes today` | write with approval |
| `Agents/` | agents' own notes and logs | write with approval |
| `Personal/`, `Wife/` | each person's own notes | write with approval, when asked |
| `AGENTS.md` | the rules agents follow | read only, always |

`Wife/` is a placeholder: rename it in Obsidian (and in `folders` in
`configs/notes/default.nix`, or the rebuild recreates an empty `Wife/`). To make a folder
read-only for agents, list it in `NOTES_PROTECTED` (comma-separated; none by default).

## Pieces (all in this repo)

- `configs/notes/core.mjs`: the rules every way in shares (paths, protected folders, write
  plans that refuse to clobber a synced edit, grants, the outbox).
- `configs/notes/index.ts`: Pi's `notes_search`, `notes_read`, `notes_recent`, `notes_write`.
  A write asks in Pi (Allow once / Always for this file / Deny, with the diff); with no one to
  ask it goes to the outbox. Under `pis` the vault is read-only and writes go through a broker
  in `configs/pi-sandbox/pi-sandbox.mjs`, signed with a per-run key passed on fd 3.
- `configs/notes/mcp.mjs` (`notes-mcp`): the same tools for Claude Code. It asks with an MCP
  elicitation dialog; `claude -p` (no one to answer) queues to the outbox.
- `configs/notes/notes.mjs` (`notes`): `notes review` (the outbox), `notes grants`,
  `notes revoke PATH`.
- `nvim/lua/notes.lua`: `:Notes` (find), `search`, `new`, `today`, `links`, `backlinks`, `tags`,
  `review`, `grants`. obsidian.nvim (`nvim/lua/plugins/obsidian.lua`, v3.16.9 pinned by commit)
  loads only with `:Notes`: then `gd` follows a `[[link]]` and `grr` lists backlinks. It adds no
  keymaps or frontmatter.
- `configs/notes/default.nix`: the tools, the vault's folders, the Mac's Syncthing.
- `modules/notes-sync.nix`: the desktop's Syncthing and the hourly git snapshot
  (`git -C ~/Notes log`; local only, never pushed).
- State outside the vault: `~/.local/state/notes/grants.json` and `outbox/`.

## One-time setup

After rebuilding both machines:

1. **Mac GUI**: http://127.0.0.1:8384. **Desktop GUI**: `ssh -L 8385:127.0.0.1:8384 desktop`,
   then http://127.0.0.1:8385. Set a GUI user and password in each (Settings → GUI).
2. **Pair the Mac and the desktop**: in each GUI, Actions → Show ID; on the other, Add Remote
   Device with that ID and, under Advanced, the address `tcp://<the other's Tailscale name or
   IP>:22000` (discovery is off, so "dynamic" won't find it).
3. **Share the folder**: on the desktop, Add Folder: label `Notes`, ID `notes`, path
   `~/Notes`, shared with the Mac. Accept it on the Mac with the path `~/Notes`.
4. Turn on file versioning for `notes` if wanted (Folder → Edit → Versioning, "Staggered").
   The desktop's hourly snapshots already keep history.

Phones (Android; done for the user's Pixel 2026-10-29). Pairing from the command line skips
the GUIs: `syncthing cli --home=<config dir> config devices add --device-id ID --name NAME`
and `config folders notes devices add --device-id ID` on the desktop
(`~/.config/syncthing`).

1. Tailscale on the phone, signed in, with Android's Always-on VPN for Tailscale (Settings →
   Network & internet → VPN → Tailscale gear). Leave "Block connections without VPN" off, or
   the phone loses internet whenever Tailscale is down. Her phone: invite her to the tailnet,
   or share only the desktop with her and limit her to port 22000 with an ACL.
2. Syncthing-Fork (Play Store or F-Droid). Settings → Connections: global discovery, local
   discovery, relays and NAT traversal off.
3. Add Device: the desktop's ID, addresses
   `tcp://desktop.TAILNET.ts.net:22000, tcp://100.64.96.125:22000` (Syncthing tries each).
   The name alone failed on the Pixel ("no such host": Syncthing on Android may not use
   Tailscale's DNS), so the IP stays as the fallback. The IP is fixed while the desktop stays
   in the tailnet, and it's also baked into the desktop's listen address (modules/notes-sync.nix).
   Add the phone on the desktop and share `notes` with it.
4. Accept `notes` and type the full path, `/storage/emulated/0/Documents/Vault` (an empty,
   new folder). The accept dialog can leave the path blank and refuse ("folder path must not
   be empty"), and it refuses a folder that already has files. Allow "manage all files".
   Folder → Ignore patterns: `.git`, `.obsidian/workspace*`, `.trash`.
5. Obsidian → Open folder as vault → `Documents/Vault`.
6. Keep it running: Android Settings → Apps → Syncthing-Fork and Tailscale → Battery →
   Unrestricted. Syncthing-Fork → Settings → Behaviour: start on boot. Silence the always-on
   notifications (long-press → Silent), rather than swiping them away: a swiped one comes
   back after a restart, and the app keeps running either way.

## Notes

- Sync is tailnet-only: Syncthing listens on each machine's Tailscale address, discovery and
  relays off, GUI on 127.0.0.1. `pis` can't reach Syncthing (the sandbox allows only the
  gateway's ports on the desktop).
- Grants are global: "Always for this file" lets every agent in every project write that file
  without asking. `notes grants` / `:Notes grants` to see and revoke them.
- Plain `pi` blocks bash commands that write into the vault on a best-effort basis; `pis`
  enforces it (read-only mount). Claude Code denies Edit/Write on `~/Notes/**`, but its bash
  isn't blocked.
