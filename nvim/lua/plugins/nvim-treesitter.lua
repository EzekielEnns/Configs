return {
	{
		"nvim-treesitter/nvim-treesitter",
		-- branch = "master", -- not needed; remove the wrong "main"
		lazy = false,
		build = ":TSUpdate",
		opts = {
			ensure_installed = {
				"lua",
				"vim",
				"vimdoc",
				"query",
				"markdown",
				"markdown_inline",
				"bash",
				"javascript",
				"typescript",
				"go",
				"python",
				"rust",
				"html",
				"css",
				"json",
				"yaml",
				"c_sharp",
			},
			auto_install = true,
			highlight = { enable = true },
			indent = { enable = true },
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "gnn",
					node_incremental = "grn",
					scope_incremental = "grc",
					node_decremental = "grm",
				},
			},
			-- This section is fine even if the plugin loads later
			textobjects = { enable = true },
		},
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		event = "VeryLazy",
	},
}
