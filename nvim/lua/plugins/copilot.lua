return {
	"github/copilot.vim",
	event = "InsertEnter",
	config = function()
		-- Disable default tab mapping
		vim.g.copilot_no_tab_map = true
		
		-- Disable copilot by default
		vim.g.copilot_enabled = false
		
		-- Set up custom accept function
		vim.keymap.set("i", "<C-J>", 'copilot#Accept("")', {
			expr = true,
			replace_keycodes = false,
			silent = true,
		})
		
		-- Accept word
		vim.keymap.set("i", "<C-K>", 'copilot#AcceptWord("")', {
			expr = true,
			replace_keycodes = false,
			silent = true,
		})
		
		-- Accept line
		vim.keymap.set("i", "<C-L>", 'copilot#AcceptLine("")', {
			expr = true,
			replace_keycodes = false,
			silent = true,
		})
	end,
}