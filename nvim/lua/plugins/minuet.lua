return {
	"milanglacier/minuet-ai.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	build = "make",
	opts = {
		provider = "openai_fim",
		remote_url = "http://192.168.1.6:9001", -- llama.cpp base
		model = "gpt-3.5-turbo",
		request_params = { temperature = 0.1, max_tokens = 128 },
	},
}
