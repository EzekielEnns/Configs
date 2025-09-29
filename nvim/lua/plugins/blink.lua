return {
	"saghen/blink.cmp",
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
			["<C-space>"] = {
				function(cmp)
					cmp.show({ providers = { "minuet" } })
				end,
			},
		},
		appearance = { nerd_font_variant = "mono" },
		completion = {
			trigger = { show_in_snippet = true },
			documentation = { auto_show = true },
			ghost_text = {
				enabled = true,
				show_with_menu = true,
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
									icon = require("lspkind").symbolic(ctx.kind, { mode = "symbol" })
								end
								return icon .. ctx.icon_gap
							end,
							highlight = function(ctx)
								local hl = ctx.kind_hl
								if vim.tbl_contains({ "Path" }, ctx.source_name) then
									local _, dev_hl = require("nvim-web-devicons").get_icon(ctx.label)
									if dev_hl then
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
		signature = { enabled = true },
		sources = {
			default = { "lsp", "path", "buffer", "minuet", "snippets" },
			providers = {
				minuet = {
					name = "minuet",
					module = "minuet.blink",
					async = true, -- 👈 let it fetch without blocking UI
					timeout_ms = 5000, -- 👈 give llama.cpp a little time
					-- async = true,
					-- -- Should match minuet.config.request_timeout * 1000,
					-- -- since minuet.config.request_timeout is in seconds
					-- timeout_ms = 3000,
					-- score_offset = 50, -- Gives minuet higher priority among suggestions
				},
			},
		},
		fuzzy = {
			implementation = "rust",
			sorts = { "score", "sort_text", "label" },
		},
	},
	opts_extend = { "sources.default" },
}
