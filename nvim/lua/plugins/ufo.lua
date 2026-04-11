return {
	"kevinhwang91/nvim-ufo",
	dependencies = { "kevinhwang91/promise-async" },
	event = { "BufReadPost", "BufNewFile" },
	init = function()
		vim.o.foldcolumn = "1"
		vim.o.foldlevel = 99
		vim.o.foldlevelstart = 99
		vim.o.foldenable = true
	end,
	config = function()
		local ufo = require("ufo")
		ufo.setup({
			provider_selector = function(_, filetype, _)
				local ft_map = {
					vim = "indent",
					python = { "indent" },
					git = "",
				}
				return ft_map[filetype] or { "treesitter", "indent" }
			end,
		})

		vim.keymap.set("n", "zR", ufo.openAllFolds, { desc = "open all folds" })
		vim.keymap.set("n", "zM", ufo.closeAllFolds, { desc = "close all folds" })
		vim.keymap.set("n", "zr", ufo.openFoldsExceptKinds, { desc = "open folds except kinds" })
		vim.keymap.set("n", "zm", "za", { desc = "toggle nearest fold", remap = true })
		vim.keymap.set("n", "K", function()
			local winid = ufo.peekFoldedLinesUnderCursor()
			if not winid then
				vim.lsp.buf.hover()
			end
		end, { desc = "ufo peek / hover" })
	end,
}
