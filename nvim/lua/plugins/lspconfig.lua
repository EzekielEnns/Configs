return {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        "ray-x/lsp_signature.nvim",
    },
    priority = 1000,
    config = function()
        vim.diagnostic.config({ virtual_text = true })
        vim.lsp.set_log_level("off")

        local lspconfig = require("lspconfig")

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
        lspconfig.gdscript.setup({})
        lspconfig.gopls.setup({
            settings = {
                gopls = {
                    completeUnimported = true,
                    usePlaceholders = true,
                },
            },
        })
        lspconfig.terraformls.setup({})
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
                        library = vim.api.nvim_get_runtime_file("", true),
                        checkThirdParty = false,
                    },
                    telemetry = {
                        enable = false,
                    },
                },
            },
        })
        lspconfig.svelte.setup({})

        -- TypeScript/JavaScript LSP
        lspconfig.ts_ls.setup({
            settings = {
                typescript = {
                    inlayHints = {
                        includeInlayParameterNameHints = "all",
                        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                        includeInlayFunctionParameterTypeHints = true,
                        includeInlayVariableTypeHints = true,
                        includeInlayPropertyDeclarationTypeHints = true,
                        includeInlayFunctionLikeReturnTypeHints = true,
                        includeInlayEnumMemberValueHints = true,
                    },
                },
                javascript = {
                    inlayHints = {
                        includeInlayParameterNameHints = "all",
                        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                        includeInlayFunctionParameterTypeHints = true,
                        includeInlayVariableTypeHints = true,
                        includeInlayPropertyDeclarationTypeHints = true,
                        includeInlayFunctionLikeReturnTypeHints = true,
                        includeInlayEnumMemberValueHints = true,
                    },
                },
            },
        })

        -- Custom tsgo LSP server
        local configs = require("lspconfig.configs")
        if not configs.ts_go_ls then
            configs.ts_go_ls = {
                default_config = {
                    cmd = { "tsgo", "--lsp", "-stdio" },
                    filetypes = {
                        "javascript",
                        "javascriptreact",
                        "javascript.jsx",
                        "typescript",
                        "typescriptreact",
                        "typescript.tsx",
                    },
                    root_dir = lspconfig.util.root_pattern("tsconfig.json", "jsconfig.json", "package.json", ".git"),
                    settings = {},
                },
            }
        end
        lspconfig.ts_go_ls.setup({})

        -- EFM for eslint
        local eslint = {
            lintCommand        = "eslint_d -f visualstudio --stdin --stdin-filename ${INPUT}",
            lintStdin          = true,
            lintFormats        = { "%f(%l,%c): %m" },
            lintIgnoreExitCode = true,
            formatCommand      = "eslint_d --fix-to-stdout --stdin --stdin-filename ${INPUT}",
            formatStdin        = true,
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


        vim.api.nvim_create_autocmd("LspAttach", {
            callback = function(args)
                local client = vim.lsp.get_client_by_id(args.data.client_id)
                if not client then return end;
                ---@diagnostic disable-next-line: missing-parameter, param-type-mismatch
                if client.supports_method('textDocument/formatting') then
                    vim.api.nvim_create_autocmd("BufWritePre", {
                        buffer = args.buf,
                        callback = function()
                            vim.lsp.buf.format({ bufnr = args.buf, id = client.id })
                        end
                    })
                end
            end
        })
    end,
}
