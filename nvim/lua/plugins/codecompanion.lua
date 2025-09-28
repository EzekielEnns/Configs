return {
	"olimorris/codecompanion.nvim",
	dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
	opts = {
		provider = "openai",
		openai_api_key = "local",
		openai_api_base = "http://ai.lan/v1", -- your coding endpoint
		model = "code",
		behaviour = { auto_suggestions = false },
		strategies = {
			chat = {
				keymaps = { close = "<Esc>" },
				tools = {
					mcp = {
						callback = function()
							return require("mcphub.extensions.codecompanion")
						end,
						description = "Docs search (MCP)",
						opts = { requires_approval = true },
					},
				},
			},
		},
	},
}
