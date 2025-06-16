local cmp = require("cmp")

cmp.setup({
	sources = {
		{ name = "path" },
		{ name = "nvim_lsp", keyword_length = 1 },
		{ name = "buffer", keyword_length = 3 },
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
      },
	mapping = cmp.mapping.preset.insert({
		["<TAB>"] = cmp.mapping.select_next_item(),
		["<S-TAB>"] = cmp.mapping.select_prev_item(),
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

-- Use buffer source for `/` and `?`
cmp.setup.cmdline({ "/", "?" }, {
	mapping = cmp.mapping.preset.cmdline(),
	sources = {
		{ name = "buffer" },
	},
})

-- Use cmdline & path source for ':'
cmp.setup.cmdline(":", {
	mapping = cmp.mapping.preset.cmdline(),
	sources = cmp.config.sources({
		{ name = "path" },
	}, {
		{ name = "cmdline" },
	}),
	matching = { disallow_symbol_nonprefix_matching = false },
})