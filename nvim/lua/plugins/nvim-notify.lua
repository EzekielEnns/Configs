return {
	"rcarriga/nvim-notify",
	config = function()
		require("notify").setup({
			-- Choose your animation stage (optional)
			stages = "slide", -- or "fade", "static", etc.

			-- Set the render direction (this controls stacking direction)
			top_down = false, -- false = notifications stack from bottom up

			-- Anchor position of the notification window
			-- "bottom_right", "bottom_left", "top_right", "top_left", "center"
			-- bottom_right is typical for bottom placement
			-- If using legacy notify, use render='minimal' or similar
			render = "default", -- or "minimal", or your custom function
			timeout = 1500, -- milliseconds
			max_height = nil, -- or set a value
			max_width = nil, -- or set a value
			background_colour = "#000000",
			fps = 30,
		})
		vim.notify = require("notify")
	end,
}
