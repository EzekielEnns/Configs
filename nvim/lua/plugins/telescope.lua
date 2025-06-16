return {
    'nvim-telescope/telescope.nvim', tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
        require("telescope").setup({
            defaults = {
                pickers = {
                    buffer = {
                        mappings = {
                            n = {
                                ["<c-c>"] = require("telescope.actions").delete_buffer,
                            },
                            i = {
                                ["<c-c>"] = require("telescope.actions").delete_buffer,
                            },
                        },
                    },
                },
                mappings = {},
            },
        })

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
