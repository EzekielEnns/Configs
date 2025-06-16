return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "ray-x/lsp_signature.nvim",
  },
  config = function()
    vim.diagnostic.config({ virtual_text = true })
    vim.lsp.set_log_level("off")

    local lspconfig = require("lspconfig")
    local lsp_defaults = lspconfig.util.default_config
    
    -- Only setup capabilities if cmp is available
    local has_cmp, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
    if has_cmp then
      lsp_defaults.capabilities = vim.tbl_deep_extend('force', lsp_defaults.capabilities, cmp_nvim_lsp.default_capabilities())
    end

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

    -- EFM for eslint
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

    -- Auto format terraform files
    vim.api.nvim_create_autocmd({ "BufWritePre" }, {
      pattern = { "*.tf", "*.tfvars" },
      callback = function()
        vim.lsp.buf.format()
      end,
    })
  end,
}