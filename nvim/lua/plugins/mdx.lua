return {
	"davidmh/mdx.nvim",
	ft = { "mdx" },
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		require("mdx").setup()
	end,
}
