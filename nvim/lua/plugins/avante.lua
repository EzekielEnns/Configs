return {
	"yetone/avante.nvim",
	-- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
	-- ⚠️ must add this setting! ! !
	build = vim.fn.has("win32") ~= 0 and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
		or "make",
	event = "VeryLazy",
	version = false, -- Never set this value to "*"! Never!
	---@module 'avante'
	---@type avante.Config
	opts = {
		-- project-specific instructions file (keep)
		instructions_file = "avante.md",

		-- ⇩ use Ollama as the provider
		-- Avante treats Ollama as a first-class (OpenAI-compatible) provider now.
		-- Endpoint must include /v1
		provider = "ollama",
		providers = {
			ollama = {
				endpoint = "http://127.0.0.1:11434/v1",

				-- 👇 Pick ONE default model here (keep the others for quick switching)
				-- All are <=14B and known good for local coding/chat:
				--   - llama3.1:8b-instruct         (fast + reliable tool-following)
				--   - qwen2.5-coder:14b-instruct   (strong coder, bigger context helps)
				--   - qwen2.5:14b-instruct         (general instruct, good coding)
				model = "deepseek-coder-v2:16b",

				timeout = 30000, -- ms
				-- These map to OpenAI-compatible fields; Ollama ignores some (e.g. max_tokens)
				extra_request_body = {
					temperature = 0.2,
					-- max_tokens = 20480, -- optional; Ollama often ignores this
				},
			},

			-- keep an example for a hosted OpenAI-compatible too (off by default)
			-- openrouter = {
			--   __inherited_from = "openai",
			--   endpoint = "https://openrouter.ai/api/v1",
			--   api_key_name = "OPENROUTER_API_KEY",
			--   model = "deepseek/deepseek-coder",
			--   timeout = 30000,
			--   extra_request_body = { temperature = 0.2 },
			-- },
		},
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"echasnovski/mini.pick",
		"nvim-telescope/telescope.nvim",
		"hrsh7th/nvim-cmp",
		"ibhagwan/fzf-lua",
		"stevearc/dressing.nvim",
		"folke/snacks.nvim",
		"nvim-tree/nvim-web-devicons",
		"zbirenbaum/copilot.lua",
		{
			"HakonHarnes/img-clip.nvim",
			event = "VeryLazy",
			opts = {
				default = {
					embed_image_as_base64 = false,
					prompt_for_file_name = false,
					drag_and_drop = { insert_mode = true },
					use_absolute_path = true, -- required on Windows
				},
			},
		},
		{
			"MeanderingProgrammer/render-markdown.nvim",
			opts = { file_types = { "markdown", "Avante" } },
			ft = { "markdown", "Avante" },
		},
	},
}
