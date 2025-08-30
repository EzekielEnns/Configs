return {
	"github/copilot.vim",
	event = "InsertEnter",
	opt = {
		suggestion = { enabled = false },
		panel = { enabled = false },
	},
	config = function()
		-- Disable default tab mapping
		vim.g.copilot_no_tab_map = true
		-- Disable copilot by default
		--
		--
		vim.g.copilot_enabled = false
		-- Set up custom accept function
		vim.keymap.set("i", "<M-space>", 'copilot#Accept("")', {
			expr = true,
			replace_keycodes = false,
			silent = true,
		})
	end,
}
