-- obsidian.nvim for the shared notes vault (~/Notes): links, backlinks, tags, completion of
-- [[links]]. Approved 2026-10-29 at v3.16.9, pinned to that tag's commit. Never loads on its
-- own (no ft/event/keys): :Notes (plugins/notes.lua) loads it and sets it up.
return {
	"obsidian-nvim/obsidian.nvim",
	commit = "a562bedd7b418a289b005cb4c62b1fe79066253b", -- v3.16.9
	lazy = true,
}
