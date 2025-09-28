return {
	"milanglacier/minuet-ai.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	build = "make",
	opts = {
		provider = "openai_fim",
		remote_url = "http://ai.lan", -- llama.cpp base
		model = "code",
		request_params = { temperature = 0.1, max_tokens = 128 },
	},
}
