-- :Notes, the shared notes vault (lua/notes.lua). Not a plugin: a virtual spec so lazy.nvim
-- defines the command and loads the module (and obsidian.nvim) on first use. Pickers are snacks'.
return {
	name = "notes",
	dir = vim.fn.stdpath("config") .. "/notes", -- an identifier only: virtual specs have no files
	virtual = true,
	cmd = "Notes",
	dependencies = { "folke/snacks.nvim", "obsidian-nvim/obsidian.nvim" },
	config = function()
		require("notes").setup()
	end,
}
