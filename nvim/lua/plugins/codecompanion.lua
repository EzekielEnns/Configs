return {
	"olimorris/codecompanion.nvim",
	dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
	opts = {
		provider = "openai",
		openai_api_key = "local", -- any non-empty string
		openai_api_base = "http://192.168.1.6:9001/v1", -- your coding endpoint
		model = "gpt-3.5-turbo", -- llama.cpp ignores name when 1 model is loaded
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
