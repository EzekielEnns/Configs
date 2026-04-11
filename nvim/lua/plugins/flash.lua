return {
	"folke/flash.nvim",
	event = "VeryLazy",
	opts = {},
	config = function(_, opts)
		require("flash").setup(opts)

		-- make jump labels pop: bright bg + bold white text
		local function apply_flash_hl()
			vim.api.nvim_set_hl(0, "FlashLabel", {
				bg = "#fb7185",
				fg = "#1d2021",
				bold = true,
			})
			vim.api.nvim_set_hl(0, "FlashMatch", {
				fg = "#a89984",
				bg = "NONE",
			})
			vim.api.nvim_set_hl(0, "FlashCurrent", {
				fg = "#ebdbb2",
				bg = "#3c3836",
			})
			vim.api.nvim_set_hl(0, "FlashBackdrop", {
				fg = "#504945",
			})
		end
		apply_flash_hl()
		vim.api.nvim_create_autocmd("ColorScheme", {
			pattern = "*",
			callback = apply_flash_hl,
		})
	end,
	keys = {
		{
			"s",
			mode = { "n", "x", "o" },
			function()
				require("flash").jump()
			end,
			desc = "Flash",
		},
		{
			"S",
			mode = { "n", "x", "o" },
			function()
				require("flash").treesitter()
			end,
			desc = "Flash Treesitter",
		},
		{
			"r",
			mode = "o",
			function()
				require("flash").remote()
			end,
			desc = "Remote Flash",
		},
		{
			"R",
			mode = { "o", "x" },
			function()
				require("flash").treesitter_search()
			end,
			desc = "Treesitter Search",
		},
		{
			"<c-s>",
			mode = { "c" },
			function()
				require("flash").toggle()
			end,
			desc = "Toggle Flash Search",
		},
	},
}
