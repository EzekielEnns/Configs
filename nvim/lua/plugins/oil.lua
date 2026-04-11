local function oil_prompt_insert(suffix, prompt)
	vim.ui.input({ prompt = prompt }, function(name)
		if not name or name == "" then
			return
		end
		local lnum = vim.api.nvim_win_get_cursor(0)[1]
		vim.api.nvim_buf_set_lines(0, lnum, lnum, false, { name .. (suffix or "") })
	end)
end

return {
	"stevearc/oil.nvim",
	lazy = false,
	dependencies = { "nvim-tree/nvim-web-devicons" },
	keys = {
		{ "-", "<cmd>Oil<cr>", desc = "Open parent directory (oil)" },
	},
	opts = {
		default_file_explorer = true,
		delete_to_trash = true,
		skip_confirm_for_simple_edits = true,
		view_options = {
			show_hidden = true,
		},
		float = {
			padding = 2,
			max_width = 100,
			max_height = 0,
		},
		keymaps = {
			["q"] = { "actions.close", mode = "n" },
			["<Esc>"] = { "actions.close", mode = "n" },
			["%"] = {
				callback = function()
					oil_prompt_insert("", "New file: ")
				end,
				desc = "new file (netrw style — :w to commit)",
				mode = "n",
			},
			["D"] = {
				callback = function()
					oil_prompt_insert("/", "New directory: ")
				end,
				desc = "new directory (netrw style — :w to commit)",
				mode = "n",
			},
		},
	},
}
