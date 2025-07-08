return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	dependencies = {
		"nvim-telescope/telescope.nvim",
		"simeji/winresizer",
		"f-person/git-blame.nvim",
		"sindrets/diffview.nvim",
	},
	config = function()
		vim.g.mapleader = " "
		local wk = require("which-key")

		wk.add({
			{ "<leader>f", "<cmd>Telescope find_files<CR>", desc = "find files" },
			{ "<leader>wr", "<cmd>WinResizerStartResize<cr>", desc = "Resize window" },
			{ "<leader>w", "<cmd>set list!<CR>", desc = "toggle white space" },
			{ "<leader>b", "<cmd>Telescope buffers<CR>", desc = "find buffers" },
			{ "<leader>/", "<cmd>Telescope live_grep<CR>", desc = "find text" },
			{ "<leader>d", "<cmd>Telescope diagnostics<CR>", desc = "look through diag" },
			{ "<leader>ls", "<cmd>Telescope lsp_document_symbols<CR>", desc = "document symbols" },
			{ "<leader>lw", "<cmd>Telescope lsp_workspace_symbols<CR>", desc = "workspace symbols" },
			{ "<leader>lr", "<cmd>Telescope lsp_references<CR>", desc = "references" },
			{ "<leader>le", "<cmd>Telescope lsp_document_diagnostics<CR>", desc = "diagnostics" },
			{ "<leader>li", "<cmd>Telescope lsp_implementations<CR>", desc = "implementation" },

			{ "<leader>cd", "<cmd>lua folder_finder()<cr>", desc = "find Directory" },
			{ "<leader>ev", "<cmd>Vex!<cr>", desc = "Explorer" },
			{ "<leader>es", "<cmd>Sex!<cr>", desc = "Explorer" },
			{ "<leader>ee", "<cmd>Exp!<cr>", desc = "Explorer" },
			{ "<leader>el", "<cmd>Lexplore!<cr>", desc = "Explorer" },
			{ "<leader>gb", "<cmd>GitBlameToggle<CR>", desc = "git blame" },
			{ "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "git diff open" },
			{ "<leader>gc", "<cmd>DiffviewClose<CR>", desc = "git diff close" },

			{ "<leader>h", "<cmd>lua vim.lsp.buf.signature_help()<cr>", desc = "lsp sig help" },
			{ "<leader>lh", "<cmd>lua vim.lsp.buf.hover()<cr>", desc = "hover" },
			{ "<leader>lH", "<cmd>lua vim.diagnostic.open_float()<cr>", desc = "diagnostic" },
			{ "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>", desc = "code action" },
			{ "<leader>r", "<cmd>lua vim.lsp.buf.rename()<cr>", desc = "rename" },
			{ "<leader>lt", "<cmd>Telescope lsp_type_definitions<CR>", desc = "type definition" },
			{ "<leader>]", "<cmd>lua vim.diagnostic.goto_prev()<cr>", desc = "prev diagnostic" },
			{ "<leader>[", "<cmd>lua vim.diagnostic.goto_next()<cr>", desc = "next diagnostic" },

			{ "<leader>p", '"+p', desc = "paste from clip", mode = { "v", "n" } },
			{ "<leader>P", '"+P', desc = "paste from clip", mode = { "v", "n" } },
			{ "<leader>y", '"+y', desc = "yank to clip", mode = { "v", "n" } },
			{ "<leader>yy", '"+yy', desc = "yank line to clip", mode = { "v", "n" } },
			{ "<leader>Y", '"+yg_', desc = "yank line", mode = { "v", "n" } },
			{ "<leader>tr", "<cmd>setlocal relativenumber!<CR>", desc = "toggle relative lines", mode = { "v", "n" } },

			-- New shortcut for copying cursor location
			{
				"<leader>cl",
				function()
					local root = vim.fn.getcwd()
					local file = vim.fn.expand("%:p")
					local rel_path = vim.fn.fnamemodify(file, ":~:.")
					if file:find(root, 1, true) == 1 then
						rel_path = file:sub(#root + 2)
					end
					local pos = rel_path .. ":" .. vim.fn.line(".") .. ":" .. vim.fn.col(".")
					vim.fn.setreg("+", pos)
					vim.notify("Copied cursor location:\n" .. pos)
				end,
				desc = "copy cursor location relative to root",
			},
		})
	end,
}
