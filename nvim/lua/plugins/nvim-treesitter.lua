return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			local ts = require("nvim-treesitter")

			ts.setup()

			-- The main branch dropped the module system: no ensure_installed,
			-- highlight, indent or incremental_selection options. Parsers are
			-- installed explicitly and features are turned on per buffer below.
			ts.install({
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
				"gomod",
				"gosum",
				"gowork",
				"python",
				"rust",
				"html",
				"css",
				"json",
				"yaml",
				"c_sharp",
				"tsx",
				"sql",
			})

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("treesitter_features", { clear = true }),
				callback = function(args)
					local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
					if not lang or not pcall(vim.treesitter.start, args.buf, lang) then
						return
					end
					vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		event = "VeryLazy",
	},
}
