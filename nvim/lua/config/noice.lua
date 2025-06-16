require("noice").setup({
	health = {
		checker = true,
	},
	views = {
		cmdline_popup = {
			position = {
				row = "90%",
				col = "50%",
			},
			size = {
				width = 60,
				height = "auto",
			},
			border = {
				style = "rounded",
			},
			win_options = {
				winhighlight = { Normal = "Normal", FloatBorder = "FloatBorder" },
			},
		},
	},
	lsp = {
		override = {
			["vim.lsp.util.convert_input_to_markdown_lines"] = true,
			["vim.lsp.util.stylize_markdown"] = true,
			["cmp.entry.get_documentation"] = true,
		},
	},
	presets = {
		bottom_search = true,
		command_palette = true,
		long_message_to_split = true,
		inc_rename = false,
		lsp_doc_border = false,
	},
})