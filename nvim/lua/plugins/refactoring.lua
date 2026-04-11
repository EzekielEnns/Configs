return {
	"ThePrimeagen/refactoring.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("refactoring").setup({})

		local r = require("refactoring")
		vim.keymap.set("x", "<leader>re", function()
			r.refactor("Extract Function")
		end, { desc = "extract function" })
		vim.keymap.set("x", "<leader>rf", function()
			r.refactor("Extract Function To File")
		end, { desc = "extract function to file" })
		vim.keymap.set("x", "<leader>rv", function()
			r.refactor("Extract Variable")
		end, { desc = "extract variable" })
		vim.keymap.set({ "n", "x" }, "<leader>ri", function()
			r.refactor("Inline Variable")
		end, { desc = "inline variable" })
		vim.keymap.set("n", "<leader>rb", function()
			r.refactor("Extract Block")
		end, { desc = "extract block" })
		vim.keymap.set("n", "<leader>rbf", function()
			r.refactor("Extract Block To File")
		end, { desc = "extract block to file" })
		vim.keymap.set({ "n", "x" }, "<leader>rr", function()
			r.select_refactor()
		end, { desc = "select refactor" })
	end,
}
