vim.diagnostic.config({ virtual_text = true })
vim.lsp.set_log_level("off")
require("trouble").setup({})
local lspconfig = require("lspconfig")
local lsp_defaults = lspconfig.util.default_config
local cap = vim.tbl_deep_extend('force', lsp_defaults.capabilities,require('cmp_nvim_lsp').default_capabilities())
lsp_defaults.capabilities = cap
vim.api.nvim_create_autocmd("LspAttach", {
	desc = "LSP actions",
	callback = function(event)
		local opts = { buffer = event.buf }
		vim.keymap.set("n", "gd", "<cmd>lua vim.lsp.buf.definition()<cr>", opts)
	end,
})
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local bufnr = args.buf
		require("lsp_signature").on_attach({
			bind = true,
			hint_enable = true,
			toggle_key = "<M-f>",
			floating_window = false,
			handler_opts = {
				border = "shadow",
			},
		}, bufnr)
	end,
})

require("typescript-tools").setup {
  settings = {
    tsserver_file_preferences = {
      includeInlayParameterNameHints = "all",
      includeCompletionsForModuleExports = true,
      quotePreference = "auto",
      importModuleSpecifierPreference= "non-relative",
      updateImportsOnFileMove= "always",
      importModuleSpecifierEnding="minimal"
    },
    separate_diagnostic_server = false,
    publish_diagnostic_on = "change",
    expose_as_code_action = {},
    tsserver_max_memory = "auto",
    tsserver_locale = "en",
    complete_function_calls = false,
    include_completions_with_insert_text = true,
    code_lens = "off",
    disable_member_code_lens = false,
    jsx_close_tag = {
        enable = true,
        filetypes = { "javascriptreact", "typescriptreact" },
    }
  },
}
local handlers = {
	["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded", silent = true }),
	["textDocument/signatureHelp"] = vim.lsp.with(
		vim.lsp.handlers.signature_help,
		{ border = "rounded", silent = true }
	),
	["textDocument/publishDiagnostics"] = vim.lsp.with(
		vim.lsp.diagnostic.on_publish_diagnostics,
		{ virtual_text = true }
	),
}
require('lspconfig').gdscript.setup({})
--require("lspconfig").eslint.setup({})
require("lspconfig").gopls.setup({
	settings = {
		gopls = {
			completeUnimported = true,
			usePlaceholders = true,
		},
	},
})
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



local eslint = {
  lintCommand  = "eslint_d -f visualstudio --stdin --stdin-filename ${INPUT}",
  lintStdin    = true,
  lintFormats  = { "%f(%l,%c): %m" },
  lintIgnoreExitCode = true,
  formatCommand = "eslint_d --fix-to-stdout --stdin --stdin-filename ${INPUT}",
  formatStdin   = true,
}

lspconfig.efm.setup({
  init_options = { documentFormatting = true, codeAction = true },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  settings = {
    languages = {
      javascript = { eslint },
      typescript = { eslint },
    },
  },
})


vim.lsp.config("ts_go_ls", {
    cmd = { "tsgo", "lsp", "-stdio" },
    filetypes = {
        "javascript",
        "javascriptreact",
        "javascript.jsx",
        "typescript",
        "typescriptreact",
        "typescript.tsx",
    },
    root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
})
