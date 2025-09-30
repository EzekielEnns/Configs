return {

	"nvim-treesitter/nvim-treesitter",
	branch = "main", -- or "main" once they switch
	lazy = false, -- 👈 important
	build = ":TSUpdate",
	dependencies = {
		"nvim-treesitter/nvim-treesitter-textobjects",
	},
	config = function()
		require("nvim-treesitter.configs").setup({
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
			textobjects = { enable = true },
		})
	end,
	-- "nvim-treesitter/nvim-treesitter",
	-- event = { "BufReadPost", "BufNewFile" },
	-- build = ":TSUpdate",
	-- dependencies = {
	--   "nvim-treesitter/nvim-treesitter-textobjects",
	-- },
	-- config = function()
	--   require("nvim-treesitter.configs").setup({
	--     highlight = {
	--       enable = true,
	--     },
	--     ensure_installed = {
	--       "lua",
	--       "javascript",
	--       "typescript",
	--       "go",
	--       "python",
	--       "rust",
	--       "html",
	--       "css",
	--       "json",
	--       "yaml",
	--       "markdown",
	--       "bash",
	--     },
	--     auto_install = true,
	--   })
	-- end,
}
