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
			--nav
			{ "<leader>f", "<cmd>Telescope find_files<CR>", desc = "find files" },
			{ "<leader><C-w>", "<cmd>WinResizerStartResize<cr>", desc = "Resize window" },
			{ "<leader>s", "<cmd>Telescope git_status<CR>", desc = "find buffers" },
			{ "<leader>w", "<cmd>set list!<CR>", desc = "toggle white space" },
			{ "<leader>b", "<cmd>Telescope buffers<CR>", desc = "find buffers" },
			{ "<leader>/", "<cmd>Telescope live_grep<CR>", desc = "find text" },
			{ "<leader>j", "<cmd>Telescope jumplist<CR>", desc = "find text" },
			{ "<leader>m", "<cmd>Telescope marks<CR>", desc = "find text" },
			{ "<leader>d", "<cmd>Telescope diagnostics<CR>", desc = "look through diag" },
			--lsp
			{ "<leader>ls", "<cmd>Telescope lsp_document_symbols<CR>", desc = "document symbols" },
			{ "<leader>lw", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", desc = "workspace symbols" },
			{ "<leader>lr", "<cmd>Telescope lsp_references<CR>", desc = "references" },
			{ "<leader>li", "<cmd>Telescope lsp_implementations<CR>", desc = "implementation" },

			--explore
			{ "<leader>cd", "<cmd>lua folder_finder()<cr>", desc = "find Directory" },
			{ "<leader>ev", "<cmd>Vex!<cr>", desc = "Explorer" },
			{ "<leader>es", "<cmd>Sex!<cr>", desc = "Explorer" },
			{ "<leader>ee", "<cmd>Exp!<cr>", desc = "Explorer" },
			{ "<leader>el", "<cmd>Lexplore!<cr>", desc = "Explorer" },

			--git
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

			--helpful
			{ "<leader>tr", "<cmd>setlocal relativenumber!<CR>", desc = "toggle relative lines", mode = { "v", "n" } },
			{ "<leader>nh", "<cmd>nohlsearch<CR>", desc = "toggle highlight", mode = { "v", "n" } },
			{ "<leader>p", '"+p', desc = "paste from clip", mode = { "v", "n" } },
			{ "<leader>P", '"+P', desc = "paste from clip", mode = { "v", "n" } },
			{ "<leader>y", '"+y', desc = "yank to clip", mode = { "v", "n" } },
			{ "<leader>yy", '"+yy', desc = "yank line to clip", mode = { "v", "n" } },
			{ "<leader>Y", '"+yg_', desc = "yank line", mode = { "v", "n" } },
			{
				"<leader>cf",
				function()
					-- Base name (filename only)
					local base = vim.fn.expand("%:t")
					vim.fn.setreg("+", base)
					vim.notify("Copied file name:\n" .. base)
				end,
				desc = "copy base file name",
			},

			{
				"<leader>cp",
				function()
					-- Base path (directory), relative to cwd (same logic as your snippet)
					local root = vim.fn.getcwd()
					local dir = vim.fn.expand("%:p:h")
					local rel = vim.fn.fnamemodify(dir, ":~:.")
					if dir:find(root, 1, true) == 1 then
						rel = dir:sub(#root + 2)
					end
					vim.fn.setreg("+", rel)
					vim.notify("Copied directory path:\n" .. rel)
				end,
				desc = "copy base path (directory) relative to root",
			},

			{
				"<leader>cl",
				function()
					-- Line number only
					local line = tostring(vim.fn.line("."))
					vim.fn.setreg("+", line)
					vim.notify("Copied line number:\n" .. line)
				end,
				desc = "copy line number",
			},
			{
				"<leader>cr",
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
			{
				"<leader>ch",
				function()
					local line = vim.api.nvim_get_current_line()
					local row = vim.api.nvim_win_get_cursor(0)[1]
					local col = vim.api.nvim_win_get_cursor(0)[2]

					if #line <= 100 then
						return
					end

					local indent = line:match("^%s*")
					local content = line:sub(#indent + 1)

					local parts = {}
					while #content > 0 do
						local max_len = 100 - #indent
						if #content <= max_len then
							table.insert(parts, indent .. content)
							break
						end

						-- Find the last space before the 100-character limit
						local cut_pos = nil
						for i = max_len, 1, -1 do
							if content:sub(i, i):match("%s") then
								cut_pos = i
								break
							end
						end

						-- If no space found, don't split this line
						if not cut_pos then
							table.insert(parts, indent .. content)
							break
						end

						table.insert(parts, indent .. content:sub(1, cut_pos - 1))
						content = content:sub(cut_pos + 1):gsub("^%s+", "")
					end

					vim.api.nvim_buf_set_lines(0, row - 1, row, false, parts)
					vim.api.nvim_win_set_cursor(0, { row, math.min(col, #parts[1]) })
				end,
				desc = "chop line at 100 chars",
			},
		})
	end,
}
