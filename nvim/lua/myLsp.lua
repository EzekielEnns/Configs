vim.diagnostic.config({ virtual_text = true })
vim.lsp.set_log_level("off")
--lsp
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local bufnr = args.buf
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if vim.tbl_contains({ "null-ls" }, client.name) then -- blacklist lsp
			return
		end
		require("lsp_signature").on_attach({
			bind = true, -- This is mandatory, otherwise border config won't get registered.
			hint_enable = true,
			--TODO setup
			toggle_key = "<M-f>",
			floating_window = false,
			handler_opts = {
				border = "shadow",
			},
		}, bufnr)
	end,
})
require("trouble").setup({})
local lspconfig = require("lspconfig")

-- require("typescript-tools").setup {
--   settings = {
--     tsserver_file_preferences = {
--       includeInlayParameterNameHints = "all",
--       includeCompletionsForModuleExports = true,
--       quotePreference = "auto",
--       importModuleSpecifierPreference= "non-relative",
--       updateImportsOnFileMove= "always",
--       importModuleSpecifierEnding="minimal"
--     },
--     separate_diagnostic_server = false,
--     publish_diagnostic_on = "change",
--     expose_as_code_action = {},
--     tsserver_max_memory = "auto",
--     tsserver_locale = "en",
--     complete_function_calls = false,
--     include_completions_with_insert_text = true,
--     code_lens = "off",
--     disable_member_code_lens = false,
--     jsx_close_tag = {
--         enable = true,
--         filetypes = { "javascriptreact", "typescriptreact" },
--     }
--   },
-- }
lspconfig.tsserver.setup({
	settings = {
		typescript = {
			inlayHints = {
				includeInlayParameterNameHints = "all",
			},
			preferences = {
				includeCompletionsForModuleExports = true,
				quotePreference = "auto",
				importModuleSpecifierPreference = "non-relative",
				importModuleSpecifierEnding = "minimal",
			},
			updateImportsOnFileMove = {
				enable = "always",
			},
		},
		javascript = {
			inlayHints = {
				includeInlayParameterNameHints = "all",
			},
			preferences = {
				includeCompletionsForModuleExports = true,
				quotePreference = "auto",
				importModuleSpecifierPreference = "non-relative",
				importModuleSpecifierEnding = "minimal",
			},
			updateImportsOnFileMove = {
				enable = "always",
			},
		},
	},
})
require("lspconfig").eslint.setup({})
require("lspconfig").gopls.setup({
	settings = {
		gopls = {
			completeUnimported = true,
			usePlaceholders = true,
		},
	},
})
require("lspconfig").nil_ls.setup({})
require("lspconfig").terraformls.setup({})
lspconfig.lua_ls.setup({
	settings = {
		Lua = {
			runtime = {
				version = "LuaJIT",
			},
			diagnostics = {
				globals = { "vim" },
			},
			workspace = {
				-- Make the server aware of Neovim runtime files
				library = vim.api.nvim_get_runtime_file("", true),
				checkThirdParty = false,
			},
			telemetry = {
				enable = false,
			},
		},
	},
})
require("lspconfig").svelte.setup({})

vim.api.nvim_create_autocmd({ "BufWritePre" }, {
	pattern = { "*.tf", "*.tfvars" },
	callback = function()
		vim.lsp.buf.format()
	end,
})
require("lspconfig").rust_analyzer.setup({
	-- settings = {
	--   ['rust-analyzer'] = {
	--     diagnostics = {
	--       enable = false;
	--     }
	--   }
	-- }
})
-- vim.g.rustaceanvim = {
--   -- Plugin configuration
--   tools = { },
--   -- LSP configuration
--   server = {
--     on_attach = function(client, bufnr)
--       -- you can also put keymaps in here
--     end,
--     default_settings = {
--       -- rust-analyzer language server configuration
--       ['rust-analyzer'] = {
--       },
--     },
--   },
--   -- DAP configuration
--   dap = {
--   },
-- }

--CMP
--require("luasnip.loaders.from_vscode").lazy_load { paths = { "~/.config/snippets" } }
-- require("scissors").setup ({
--     snippetDir = "~/.config/snippets",
-- })
local lsp_defaults = lspconfig.util.default_config
local cap = vim.tbl_deep_extend("force", lsp_defaults.capabilities, require("cmp_nvim_lsp").default_capabilities())
lsp_defaults.capabilities = cap
vim.api.nvim_create_autocmd("LspAttach", {
	desc = "LSP actions",
	callback = function(event)
		local opts = { buffer = event.buf }
		vim.keymap.set("n", "gd", "<cmd>lua vim.lsp.buf.definition()<cr>", opts)
	end,
})
