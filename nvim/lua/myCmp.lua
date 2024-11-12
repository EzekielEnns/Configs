require("nvim-autopairs").setup()
local cmp = require("cmp")
local cmp_autopairs = require("nvim-autopairs.completion.cmp")
cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
cmp.setup({
	sources = {
		{ name = "path" },
		{ name = "nvim_lsp", keyword_length = 1 },
		{ name = "buffer", keyword_length = 3 },
		--{ name = 'vsnip',    keyword_length = 2 },
		{ name = 'luasnip' },
		{
			name = "spell",
			option = {
				keep_all_entries = false,
				enable_in_context = function()
					return true
				end,
			},
		},
	},
	formatting = {
		fields = { "menu", "abbr", "kind" },
		format = function(entry, item)
			local menu_icon = {
				nvim_lsp = "λ",
				luasnip = "⋗",
				buffer = "Ω",
				path = "🖫",
			}

			item.menu = menu_icon[entry.source.name]
			return item
		end,
	},

	mapping = cmp.mapping.preset.insert({
		["<TAB>"] = cmp.mapping.select_next_item(),
		["<S-TAB>"] = cmp.mapping.select_prev_item(),
		--["<>"] = cmp.mapping.select_next_item(),
		["<CR>"] = cmp.mapping.confirm({ select = false }),
		["<C-l>"] = cmp.mapping.complete(),
	}),
	snippet = {
	    expand = function(args)
            require 'luasnip'.lsp_expand(args.body)
	    end
	},
	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},
})

-- local handlers = require("nvim-autopairs.completion.handlers")

-- cmp.event:on(
-- 	"confirm_done",
-- 	cmp_autopairs.on_confirm_done({
-- 		filetypes = {
-- 			-- "*" is a alias to all filetypes
-- 			["*"] = {
-- 				["("] = {
-- 					kind = {
-- 						cmp.lsp.CompletionItemKind.Function,
-- 						cmp.lsp.CompletionItemKind.Method,
-- 					},
-- 					handler = handlers["*"],
-- 				},
-- 			},
-- 			lua = {
-- 				["("] = {
-- 					kind = {
-- 						cmp.lsp.CompletionItemKind.Function,
-- 						cmp.lsp.CompletionItemKind.Method,
-- 					},
-- 					---@param char string
-- 					---@param item table item completion
-- 					---@param bufnr number buffer number
-- 					---@param rules table
-- 					---@param commit_character table<string>
-- 					handler = function(char, item, bufnr, rules, commit_character)
-- 						-- Your handler function. Inspect with print(vim.inspect{char, item, bufnr, rules, commit_character})
-- 					end,
-- 				},
-- 			},
-- 			-- Disable for tex
-- 			tex = false,
-- 		},
-- 	})
-- )
-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline({ "/", "?" }, {
	mapping = cmp.mapping.preset.cmdline(),
	sources = {
		{ name = "buffer" },
	},
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(":", {
	mapping = cmp.mapping.preset.cmdline(),
	sources = cmp.config.sources({
		{ name = "path" },
	}, {
		{ name = "cmdline" },
	}),
	matching = { disallow_symbol_nonprefix_matching = false },
})
