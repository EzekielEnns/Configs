--https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"ray-x/lsp_signature.nvim",
		"hoffs/omnisharp-extended-lsp.nvim",
	},
	priority = 1000,
	config = function()
		vim.diagnostic.config({ virtual_text = true })
		vim.lsp.set_log_level("off")

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

		-- Language servers
		vim.lsp.config("lua_ls", {
			on_init = function(client)
				if client.workspace_folders then
					local path = client.workspace_folders[1].name
					if
						path ~= vim.fn.stdpath("config")
						and (vim.uv.fs_stat(path .. "/.luarc.json") or vim.uv.fs_stat(path .. "/.luarc.jsonc"))
					then
						return
					end
				end

				client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
					runtime = {
						-- Tell the language server which version of Lua you're using (most
						-- likely LuaJIT in the case of Neovim)
						version = "LuaJIT",
						-- Tell the language server how to find Lua modules same way as Neovim
						-- (see `:h lua-module-load`)
						path = {
							"lua/?.lua",
							"lua/?/init.lua",
						},
					},
					-- Make the server aware of Neovim runtime files
					workspace = {
						checkThirdParty = false,
						library = {
							vim.env.VIMRUNTIME,
							-- Depending on the usage, you might want to add additional paths
							-- here.
							-- '${3rd}/luv/library'
							-- '${3rd}/busted/library'
						},
						-- Or pull in all of 'runtimepath'.
						-- NOTE: this is a lot slower and will cause issues when working on
						-- your own configuration.
						-- See https://github.com/neovim/nvim-lspconfig/issues/3189
						-- library = {
						--   vim.api.nvim_get_runtime_file('', true),
						-- }
					},
				})
			end,
			settings = {
				Lua = {},
			},
		})

		-- EFM for eslint
		local eslint = {
			lintCommand = "eslint_d -f visualstudio --stdin --stdin-filename ${INPUT}",
			lintStdin = true,
			lintFormats = { "%f(%l,%c): %m" },
			lintIgnoreExitCode = true,
			formatCommand = "eslint_d --fix-to-stdout --stdin --stdin-filename ${INPUT}",
			formatStdin = true,
		}

		vim.lsp.config("efm", {
			init_options = { documentFormatting = true, codeAction = true },
			filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
			settings = {
				languages = {
					javascript = { eslint },
					typescript = { eslint },
				},
			},
		})
		--config for roslyn changed based on os
		local roslyn_exe = vim.fn.expand(
			"~/.local/share/roslyn-ls/content/LanguageServer/osx-x64/Microsoft.CodeAnalysis.LanguageServer"
		)
		vim.env.DOTNET_ROOT = (vim.uv or vim.loop).os_homedir() .. "/.dotnet/x64"
		local logdir = vim.fs.joinpath(vim.uv.os_tmpdir(), "roslyn_ls", "logs")
		vim.fn.mkdir(logdir, "p")
		vim.lsp.config("roslyn", {
			offset_encoding = "utf-8",
			cmd = {
				roslyn_exe,
				"--logLevel",
				"Information",
				"--extensionLogDirectory",
				logdir,
				"--stdio",
			},
			settings = {
				["csharp|background_analysis"] = {
					dotnet_analyzer_diagnostics_scope = "fullSolution",
					dotnet_compiler_diagnostics_scope = "fullSolution",
				},
				["csharp|code_lens"] = {
					dotnet_enable_references_code_lens = true,
				},
				["csharp|completion"] = {
					dotnet_provide_regex_completions = true,
					dotnet_show_completion_items_from_unimported_namespaces = true,
					dotnet_show_name_completion_suggestions = true,
				},
				["csharp|inlay_hints"] = {
					csharp_enable_inlay_hints_for_implicit_object_creation = true,
					csharp_enable_inlay_hints_for_implicit_variable_types = true,
					csharp_enable_inlay_hints_for_lambda_parameter_types = true,
					csharp_enable_inlay_hints_for_types = true,
					dotnet_enable_inlay_hints_for_indexer_parameters = true,
					dotnet_enable_inlay_hints_for_literal_parameters = true,
					dotnet_enable_inlay_hints_for_object_creation_parameters = true,
					dotnet_enable_inlay_hints_for_other_parameters = true,
					dotnet_enable_inlay_hints_for_parameters = true,
					dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
					dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
					dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
				},
				["csharp|symbol_search"] = {
					dotnet_search_reference_assemblies = true,
				},
			},
		})

		vim.lsp.enable({
			"roslyn_ls",
			"gdscript",
			"gopls",
			"terraformls",
			"efm",
			"lua_ls",
			"rust_analyzer",
			"csharp_ls",
			"cssls",
			"html",
			"eslint",
			"jsonls",
			"tailwindcss",
		})
	end,
}
