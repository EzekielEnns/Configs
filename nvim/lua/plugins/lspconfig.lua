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
		vim.lsp.set_log_level("OFF")

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
		local home = vim.uv.os_homedir()
		local roslyn = home
			.. "/.local/share/roslyn-ls/content/LanguageServer/neutral/Microsoft.CodeAnalysis.LanguageServer.dll"
		vim.env.DOTNET_ROOT = home .. "/.dotnet/x64"
		local logdir = vim.fs.joinpath(vim.uv.os_tmpdir(), "roslyn_ls", "logs")
		vim.fn.mkdir(logdir, "p")
		vim.lsp.config("roslyn_ls", {
			cmd = {
				"dotnet",
				roslyn,
				"--logLevel",
				"Information",
				"--extensionLogDirectory",
				logdir,
				"--stdio",
			},

			settings = {
				["csharp|background_analysis"] = {
					dotnet_compiler_diagnostics_scope = "openFiles",
					dotnet_analyzer_diagnostics_scope = "openFiles",
				},
			},
			-- on_init = function(client)
			-- 	local selected_file_for_init = find_csproj_or_sln()
			-- 	local uri = vim.uri_from_fname(selected_file_for_init)
			-- 	if selected_file_for_init:match("%.slnx?$") then
			-- 		client:notify("solution/open", { solution = uri })
			-- 	elseif selected_file_for_init:match("%.csproj$") then
			-- 		client:notify("project/open", { projects = { uri } })
			-- 	end
			-- end,
			handlers = {
				["workspace/_roslyn_projectNeedsRestore"] = function(err, params, ctx, _)
					-- run restores fire-and-forget
					local function find_proj(dir)
						return vim.fs.find({ "*.sln", "*.csproj" }, { path = dir, upward = true })[1]
					end
					local seen = {}
					for _, p in ipairs(params.paths or {}) do
						local target = find_proj(p) or find_proj(vim.fs.dirname(p))
						if target and not seen[target] then
							seen[target] = true
							vim.fn.jobstart({ "dotnet", "restore", target }, { detach = true })
						end
					end
					-- IMPORTANT: reply to the server so Neovim doesn't error
					return vim.NIL -- sends JSON null as the result
				end,
			},
		})

		-- shared capabilities (fixes offsetEncoding conflict)
		local capabilities = vim.lsp.protocol.make_client_capabilities()
		capabilities.offsetEncoding = { "utf-16" }

		vim.lsp.config("ruff", {
			capabilities = capabilities,
			init_options = {
				settings = {
					-- OPTIONAL: disable hover so basedpyright handles it
					hover = {
						enabled = false,
					},
				},
			},
		})

		vim.lsp.enable("roslyn_ls")

		vim.lsp.config("kotlin-laguage-server", {
			capabilities = capabilities,
			cmd = "kotlin-language-server",
			filetypes = { "kotlin" },
			root_markers = {
				"settings.gradle",
				"settings.gradle.kts",
				"build.xml",
				"pom.xml",
				"build.gradle",
				"build.gradle.kts",
			},
		})
		vim.lsp.enable({
			"gdscript",
			"gopls",
			"terraformls",
			"efm",
			"lua_ls",
			"rust_analyzer",
			"cssls",
			"html",
			"eslint",
			"jsonls",
			"tailwindcss",
			"basedpyright",
			"ruff",
			"kotlin-laguage-server",
		})
	end,
}
