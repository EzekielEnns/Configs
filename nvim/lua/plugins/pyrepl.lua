-- Jupyter notebooks, via a jupyter-console REPL rather than a remote plugin.
--
-- Picked over molten-nvim because it needs no pynvim rplugin host: molten wants
-- g:python3_host_prog pinned to a venv holding pynvim, which fights the uv .venv
-- autodetect in init.lua. This just shells out to jupyter-console, so the kernel
-- comes from whichever venv is active -- exactly what that autodetect sets up.
--
-- Opening a .ipynb prompts to convert it to a py:percent script (`# %%` cells);
-- <leader>ke writes the script back to the notebook, keeping existing outputs.
return {
	"dangooddd/pyrepl.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	-- BufReadPre, not BufReadPost: the conversion hook is registered by setup(),
	-- so the plugin has to be loaded before the notebook finishes reading.
	event = { "BufReadPre *.ipynb" },
	ft = { "python" },
	cmd = {
		"PyreplOpen",
		"PyreplHide",
		"PyreplClose",
		"PyreplToggle",
		"PyreplToggleFocus",
		"PyreplOpenImageHistory",
		"PyreplSendVisual",
		"PyreplSendBuffer",
		"PyreplSendCell",
		"PyreplStepCellBackward",
		"PyreplStepCellForward",
		"PyreplExport",
		"PyreplConvert",
		"PyreplInstall",
	},
	opts = {
		split_ratio = 0.4,
		-- ghostty speaks the kitty graphics protocol, so plots render without
		-- pulling in image.nvim.
		image_provider = "placeholders",
		-- derive the console's syntax colours from gruvbox
		style_integration = true,
		-- python_path stays "python": init.lua puts the project's .venv/bin on
		-- PATH, so the REPL lands in the same environment as the LSP.
		jupytext_hook = true,
	},
}
