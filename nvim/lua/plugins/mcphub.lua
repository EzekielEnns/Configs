return {
	"ravitemer/mcphub.nvim",
	build = "npm i -g mcp-hub@latest",
	config = function()
		require("mcphub").setup({
			--TODO change port
			port = 4000,
			config = vim.fn.expand("~/.config/nvim/mcpservers.json"),
		})
	end,
}
