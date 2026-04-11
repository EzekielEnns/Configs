return {
	"RRethy/vim-illuminate",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("illuminate").configure({
			providers = { "lsp", "treesitter", "regex" },
			delay = 200,
			large_file_cutoff = 2000,
		})

		-- bright rose occurrence highlights — clearly distinct from gruvbox purple
		local function apply_illuminate_hl()
			vim.api.nvim_set_hl(0, "IlluminatedWordText", { fg = "#fb7185", underline = false })
			vim.api.nvim_set_hl(0, "IlluminatedWordRead", { fg = "#fb7185", underline = false })
			vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { fg = "#f43f5e", underline = false, bold = true })
		end
		apply_illuminate_hl()
		vim.api.nvim_create_autocmd("ColorScheme", {
			pattern = "*",
			callback = apply_illuminate_hl,
		})
	end,
}
