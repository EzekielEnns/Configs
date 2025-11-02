return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.8",
	dependencies = { "nvim-lua/plenary.nvim", "debugloop/telescope-undo.nvim" },
	config = function()
		local actions = require("telescope.actions")
		require("telescope").setup({
			-- Global defaults for ALL pickers
			defaults = {
				prompt_prefix = "   ",
				selection_caret = " ",
				sorting_strategy = "ascending",

				-- 👇 change layout here
				layout_strategy = "vertical",
				layout_config = {
					vertical = {
						width = 0.55, -- 55% of screen width
						height = 0.95, -- almost full height
						prompt_position = "top",
						preview_cutoff = 10, -- never hide preview unless really tiny
						mirror = false,
					},
					-- Fallbacks (used by 'flex' or others if you switch later)
					horizontal = { preview_width = 0.6, prompt_position = "top" },
					center = { width = 0.5, height = 0.5, preview_cutoff = 0 },
					cursor = { width = 0.5, height = 0.35 },
				},

				mappings = {
					i = {
						["<Esc>"] = actions.close,
					},
					n = {},
				},
			},

			-- Per-picker tweaks (buffer list gets quick delete + same layout)
			pickers = {
				buffers = {
					sort_lastused = true,
					mappings = {
						i = { ["<C-c>"] = actions.delete_buffer },
						n = { ["<C-c>"] = actions.delete_buffer },
					},
				},
			},
		})
		require("telescope").load_extension("undo")
		-- Custom folder finder
		local pickers = require("telescope.pickers")
		local finders = require("telescope.finders")
		local conf = require("telescope.config").values
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")

		local dirs = vim.split(vim.fn.glob(vim.fn.getcwd() .. "/*/"), "\n", { trimemtpy = true })
		table.insert(dirs, vim.fn.getcwd())

		local folders = function(opts)
			opts = opts or {}
			pickers
				.new(opts, {
					prompt_title = "Pick Directory",
					finder = finders.new_table({
						results = dirs,
					}),
					sorter = conf.generic_sorter(opts),
					attach_mappings = function(prompt_bufnr, map)
						actions.select_default:replace(function()
							actions.close(prompt_bufnr)
							local selection = action_state.get_selected_entry()
							vim.api.nvim_set_current_dir(selection[1])
						end)
						return true
					end,
				})
				:find()
		end

		_G.folder_finder = folders
	end,
}
