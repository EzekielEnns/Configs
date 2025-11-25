return {
	"robitx/gp.nvim",
	config = function()
		require("gp").setup({
			-- IMPORTANT: set provider secret explicitly
			providers = {
				openai = {
					endpoint = "http://ai.lan/v1/chat/completions", -- llama-swap base
					secret = os.getenv("OPENAI_API_KEY") or "local",
				},
			},

			agents = {
				{
					name = "Local-Code",
					provider = "openai",
					model = { model = "code" }, -- your llama-swap alias
					system_prompt = [[You are a concise coding assistant. Prefer minimal, clear diffs.]],
					chat = true,
					command = true,
					temperature = 0.2,
					stream = false, -- <- return one JSON object (no SSE)
				},
			},

			default_agent = "Local-Code",
		})

		-- safe keymaps using user commands
		local map = vim.keymap.set
		map("n", "<leader>ac", "<cmd>GpAgent Local-Code | GpChatToggle<CR>", { desc = "AI: Chat (Local-Code)" })
		map("v", "<leader>ai", ":<C-U>GpAgent Local-Code | '<,'>GpRewrite<CR>", { desc = "AI: Rewrite selection" })
		map("v", "<leader>aa", ":<C-U>GpAgent Local-Code | '<,'>GpAppend<CR>", { desc = "AI: Append after selection" })
		map("n", "<leader>aI", "<cmd>GpInspectPlugin<CR>", { desc = "AI: Inspect payload/logs" })
	end,
}
