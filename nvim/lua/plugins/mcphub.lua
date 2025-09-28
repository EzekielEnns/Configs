return {
	"ravitemer/mcphub.nvim",
	build = "npm i -g mcp-hub@latest",
	config = function()
		require("mcphub").setup({
			--cant use port 3000 what do i do
			port = 3333,
			config = vim.fn.expand("~/.config/nvim/mcpservers.json"),
		})
	end,
}
