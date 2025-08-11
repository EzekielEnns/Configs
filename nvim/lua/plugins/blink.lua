return {
	"saghen/blink.cmp",
	-- optional: provides snippets for the snippet source
	dependencies = {
		"L3MON4D3/LuaSnip",
		"nvim-tree/nvim-web-devicons",
		"onsails/lspkind.nvim",
		"giuxtaposition/blink-cmp-copilot",
	},

	version = "1.*",
	opts = {
		snippets = { preset = "default" },
		keymap = {
			preset = "super-tab",
			["<C-l>"] = {
				function(cmp)
					cmp.show()
				end,
			},
		},

		appearance = {
			nerd_font_variant = "mono",
		},

		completion = {
			ghost_text = { enabled = true, show_with_menue = true },
			trigger = {
				show_in_snippet = true,
			},
			documentation = {
				auto_show = true,
			},
			menu = {
				auto_show = true,
				draw = {
					components = {
						kind_icon = {
							text = function(ctx)
								local icon = ctx.kind_icon
								if vim.tbl_contains({ "Path" }, ctx.source_name) then
									local dev_icon, _ = require("nvim-web-devicons").get_icon(ctx.label)
									if dev_icon then
										icon = dev_icon
									end
								else
									icon = require("lspkind").symbolic(ctx.kind, {
										mode = "symbol",
									})
								end

								return icon .. ctx.icon_gap
							end,

							highlight = function(ctx)
								local hl = ctx.kind_hl
								if vim.tbl_contains({ "Path" }, ctx.source_name) then
									local dev_icon, dev_hl = require("nvim-web-devicons").get_icon(ctx.label)
									if dev_icon then
										hl = dev_hl
									end
								end
								return hl
							end,
						},
					},
				},
			},
		},
		signature = {
			enabled = true,
		},
		sources = {
			default = { "lsp", "path", "buffer", "snippets", "copilot" },
			providers = {
				copilot = {
					name = "copilot",
					module = "blink-cmp-copilot",
					score_offset = 100,
					async = true,
				},
			},
		},

		-- (Default) Rust fuzzy matcher for typo resistance and significantly better performance
		fuzzy = {
			implementation = "rust",
			sorts = {
				"exact",
				-- defaults
				"score",
				"sort_text",
			},
		},
	},
	opts_extend = { "sources.default" },
}
