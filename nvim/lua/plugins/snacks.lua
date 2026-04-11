return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		bigfile = { enabled = true },
		notifier = {
			enabled = true,
			timeout = 3000,
		},
		statuscolumn = { enabled = true },
		indent = {
			enabled = true,
			indent = {
				char = "│",
				hl = "SnacksIndent",
			},
			scope = {
				char = "│",
				hl = "SnacksIndentScope",
			},
		},
		input = { enabled = true },
		picker = {
			enabled = true,
			layout = {
				preset = "vertical",
				cycle = true,
			},
		},
		dashboard = {
			enabled = true,
			preset = {
				header = table.concat({
					"",
					"  Today I shall be meeting with interference, ingratitude,",
					"  insolence, disloyalty, ill-will, and selfishness — all of",
					"  them due to the offenders' ignorance of what is good or evil.",
					"",
					"                                          — Marcus Aurelius",
					"",
				}, "\n"),
			},
			sections = {
				{ section = "header" },
				{ section = "keys", gap = 1, padding = 1 },
				{ section = "recent_files", limit = 8, padding = 1 },
				{ section = "projects", padding = 1 },
				{ section = "startup" },
			},
		},
		lazygit = { enabled = true },
		terminal = { enabled = true },
		gitbrowse = { enabled = true },
		quickfile = { enabled = true },
	},
	config = function(_, opts)
		require("snacks").setup(opts)
		vim.notify = require("snacks").notifier.notify

		-- soft indent guides — barely-there grey, scope a touch brighter
		local function apply_indent_hl()
			vim.api.nvim_set_hl(0, "SnacksIndent", { fg = "#3c3836" })
			vim.api.nvim_set_hl(0, "SnacksIndentScope", { fg = "#665c54" })
		end
		apply_indent_hl()
		vim.api.nvim_create_autocmd("ColorScheme", {
			pattern = "*",
			callback = apply_indent_hl,
		})

		-- zen dashboard palette: soft blue header, muted grey accents
		local function apply_dashboard_hl()
			vim.api.nvim_set_hl(0, "SnacksDashboardHeader", { fg = "#83a598", italic = true }) -- gruvbox soft blue
			vim.api.nvim_set_hl(0, "SnacksDashboardTitle", { fg = "#7c6f64" }) -- muted grey
			vim.api.nvim_set_hl(0, "SnacksDashboardIcon", { fg = "#928374" })
			vim.api.nvim_set_hl(0, "SnacksDashboardDesc", { fg = "#a89984" })
			vim.api.nvim_set_hl(0, "SnacksDashboardKey", { fg = "#d3869b" }) -- soft pink for hotkeys
			vim.api.nvim_set_hl(0, "SnacksDashboardFile", { fg = "#a89984" })
			vim.api.nvim_set_hl(0, "SnacksDashboardDir", { fg = "#7c6f64" })
			vim.api.nvim_set_hl(0, "SnacksDashboardFooter", { fg = "#665c54", italic = true })
			vim.api.nvim_set_hl(0, "SnacksDashboardSpecial", { fg = "#83a598" })
		end

		apply_dashboard_hl()
		vim.api.nvim_create_autocmd("ColorScheme", {
			pattern = "*",
			callback = apply_dashboard_hl,
		})
	end,
}
