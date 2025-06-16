return {
  -- LSP Configuration
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "ray-x/lsp_signature.nvim",
    },
    config = function()
      require("config.lsp")
    end,
  },

  -- TypeScript Tools
  {
    "pmizio/typescript-tools.nvim",
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    config = function()
      require("config.typescript-tools")
    end,
  },

  -- Go support
  {
    "ray-x/go.nvim",
    ft = { "go", "gomod" },
    dependencies = {
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("go").setup()
    end,
  },

  -- Linting
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("config.lint")
    end,
  },

  -- Formatting
  {
    "sbdchd/neoformat",
    cmd = { "Neoformat" },
  },

  -- Trouble diagnostics
  {
    "folke/trouble.nvim",
    cmd = { "Trouble", "TroubleToggle" },
    config = function()
      require("trouble").setup()
    end,
  },

  -- LSP progress indicator
  {
    "j-hui/fidget.nvim",
    event = "LspAttach",
    config = function()
      require("fidget").setup()
    end,
  },
}