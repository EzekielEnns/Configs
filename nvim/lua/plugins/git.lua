return {
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		opts = {
			signs = {
				add = { text = "▎" },
				change = { text = "▎" },
				delete = { text = "" },
				topdelete = { text = "" },
				changedelete = { text = "▎" },
				untracked = { text = "▎" },
			},
			signs_staged = {
				add = { text = "▎" },
				change = { text = "▎" },
				delete = { text = "" },
				topdelete = { text = "" },
				changedelete = { text = "▎" },
			},
			signs_staged_enable = true,
			sign_priority = 100,
			current_line_blame = false,
			on_attach = function(bufnr)
				local gs = require("gitsigns")
				local function map(mode, l, r, desc)
					vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
				end

				map("n", "]h", function()
					if vim.wo.diff then
						vim.cmd.normal({ "]c", bang = true })
					else
						gs.nav_hunk("next")
					end
				end, "next hunk")
				map("n", "[h", function()
					if vim.wo.diff then
						vim.cmd.normal({ "[c", bang = true })
					else
						gs.nav_hunk("prev")
					end
				end, "prev hunk")

				map("n", "<leader>ghs", gs.stage_hunk, "stage hunk")
				map("n", "<leader>ghr", gs.reset_hunk, "reset hunk")
				map("v", "<leader>ghs", function()
					gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, "stage hunk")
				map("v", "<leader>ghr", function()
					gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, "reset hunk")
				map("n", "<leader>ghp", gs.preview_hunk, "preview hunk")
				map("n", "<leader>ghu", gs.undo_stage_hunk, "undo stage hunk")
				map("n", "<leader>ghb", function()
					gs.blame_line({ full = true })
				end, "blame line")
			end,
		},
		config = function(_, opts)
			require("gitsigns").setup(opts)

			local function apply_git_highlights()
				-- unstaged → orange
				vim.api.nvim_set_hl(0, "GitSignsAdd", { fg = "#fe8019" })
				vim.api.nvim_set_hl(0, "GitSignsChange", { fg = "#fe8019" })
				vim.api.nvim_set_hl(0, "GitSignsDelete", { fg = "#fe8019" })
				vim.api.nvim_set_hl(0, "GitSignsTopdelete", { fg = "#fe8019" })
				vim.api.nvim_set_hl(0, "GitSignsChangedelete", { fg = "#fe8019" })
				vim.api.nvim_set_hl(0, "GitSignsUntracked", { fg = "#fe8019" })
				-- staged → green
				vim.api.nvim_set_hl(0, "GitSignsStagedAdd", { fg = "#b8bb26" })
				vim.api.nvim_set_hl(0, "GitSignsStagedChange", { fg = "#b8bb26" })
				vim.api.nvim_set_hl(0, "GitSignsStagedDelete", { fg = "#b8bb26" })
				vim.api.nvim_set_hl(0, "GitSignsStagedTopdelete", { fg = "#b8bb26" })
				vim.api.nvim_set_hl(0, "GitSignsStagedChangedelete", { fg = "#b8bb26" })
			end

			apply_git_highlights()
			vim.api.nvim_create_autocmd("ColorScheme", {
				pattern = "*",
				callback = apply_git_highlights,
			})
		end,
	},
	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen" },
		config = function()
			require("diffview").setup({
				diff_binaries = false, -- Show diffs for binaries
				enhanced_diff_hl = false, -- See |diffview-config-enhanced_diff_hl|
				git_cmd = { "git" }, -- The git executable followed by default args.
				hg_cmd = { "hg" }, -- The hg executable followed by default args.
				use_icons = true, -- Requires nvim-web-devicons
				show_help_hints = true, -- Show hints for how to open the help panel
				watch_index = true, -- Update views and index buffers when the git index changes.
				icons = { -- Only applies when use_icons is true.
					folder_closed = "",
					folder_open = "",
				},
				signs = {
					fold_closed = "",
					fold_open = "",
					done = "✓",
				},
				view = {
					-- Configure the layout and behavior of different types of views.
					-- Available layouts:
					--  'diff1_plain'
					--    |'diff2_horizontal'
					--    |'diff2_vertical'
					--    |'diff3_horizontal'
					--    |'diff3_vertical'
					--    |'diff3_mixed'
					--    |'diff4_mixed'
					-- For more info, see |diffview-config-view.x.layout|.
					default = {
						-- Config for changed files, and staged files in diff views.
						layout = "diff2_vertical",
						disable_diagnostics = false, -- Temporarily disable diagnostics for diff buffers while in the view.
						winbar_info = false, -- See |diffview-config-view.x.winbar_info|
					},
					merge_tool = {
						-- Config for conflicted files in diff views during a merge or rebase.
						layout = "diff3_vertical",
						disable_diagnostics = true, -- Temporarily disable diagnostics for diff buffers while in the view.
						winbar_info = true, -- See |diffview-config-view.x.winbar_info|
					},
					file_history = {
						-- Config for changed files in file history views.
						layout = "diff2_vertical",
						disable_diagnostics = false, -- Temporarily disable diagnostics for diff buffers while in the view.
						winbar_info = false, -- See |diffview-config-view.x.winbar_info|
					},
				},
				file_panel = {
					listing_style = "tree", -- One of 'list' or 'tree'
					tree_options = { -- Only applies when listing_style is 'tree'
						flatten_dirs = true, -- Flatten dirs that only contain one single dir
						folder_statuses = "only_folded", -- One of 'never', 'only_folded' or 'always'.
					},
					win_config = { -- See |diffview-config-win_config|
						position = "left",
						width = 35,
						win_opts = {},
					},
				},
			})
		end,
	},

	-- Git blame
	{
		"f-person/git-blame.nvim",
		cmd = { "GitBlameToggle" },
	},
}
