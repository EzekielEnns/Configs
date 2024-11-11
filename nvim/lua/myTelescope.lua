require("telescope").setup({
	defaults = {
		-- Default configuration for telescope goes here:
		-- config_key = value,
		pickers = {
			buffer = {
				mappings = {
					n = {
						["<c-c>"] = require("telescope.actions").delete_buffer,
					}, -- n
					i = {
						["<c-c>"] = require("telescope.actions").delete_buffer,
					}, -- i
				},
			},
		},
		mappings = {}, -- mappings
	}, -- defaults
	...,
}) -- telescope setup
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
					print(vim.inspect(selection))
					--vim.api.nvim_put({ selection[1] }, "", false, true)
					vim.api.nvim_set_current_dir(selection[1])
				end)
				return true
			end,
		})
		:find()
end

_G.folder_finder = folders
