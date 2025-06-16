return {
  -- Completion engine
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "f3fora/cmp-spell",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      require("config.cmp")
    end,
  },

  -- Snippets
  {
    "L3MON4D3/LuaSnip",
    event = "InsertEnter",
    build = "make install_jsregexp",
  },

  -- Auto pairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("config.autopairs")
    end,
  },
}