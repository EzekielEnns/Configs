-- lua/plugins/gp.lua
return {
	"robitx/gp.nvim",
	-- pin if you like: version = "*",
	config = function()
		-- Minimal, OpenAI-compatible setup
		local conf = {
			-- Tell gp.nvim to talk to your OpenAI-compatible server
			openai_api_key = os.getenv("OPENAI_API_KEY") or "local",
			-- gp.nvim supports custom “OpenAI chat/completions” endpoints
			openai_api_endpoint = "http://ai.lan/v1/chat/completions",

			-- Define an agent that uses your llama-swap model alias “code”
			agents = {
				{
					name = "Local-Code",
					provider = "openai", -- keep as 'openai' for OpenAI-compatible APIs
					chat = true,
					command = true,
					model = { model = "code" }, -- <- llama-swap model/alias
					temperature = 0.2,
				},
			},

			-- Optional: make Local-Code the default
			default_agent = "Local-Code",
		}

		require("gp").setup(conf)

		----------------------------------------------------------------
		-- Shortcuts you’ll actually use
		----------------------------------------------------------------
		local gp = require("gp")
		local map = vim.keymap.set

		-- Open/Toggle chat (scratch buffer)
		map("n", "<leader>ac", gp.chat_toggle, { desc = "AI: Chat (toggle)" })

		-- Visual selection → quick rewrite in-place
		map("v", "<leader>ai", function()
			gp.inject({ prompt = "Improve/complete this selection.", replace = true })
		end, { desc = "AI: Improve selection (replace)" })

		-- Visual selection → apply at cursor (append below)
		map("v", "<leader>aa", function()
			gp.inject({ prompt = "Generate code for this selection.", target = "append" })
		end, { desc = "AI: Generate (append)" })

		-- Line-wise: ask about current buffer context
		map("n", "<leader>aq", function()
			gp.chat({ prompt = "Answer concisely about this file." })
		end, { desc = "AI: Ask about file" })

		-- Debug: inspect what gp.nvim sent to the server last time
		map("n", "<leader>aI", "<cmd>GpInspectPlugin<cr>", { desc = "AI: Inspect payload/logs" })
	end,
}
