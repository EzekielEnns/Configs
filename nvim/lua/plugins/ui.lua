return {
  -- Color scheme
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("gruvbox")
    end,
  },

  -- Icons
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },

  -- Enhanced UI
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    config = function()
      require("config.noice")
    end,
  },

  -- Notifications
  {
    "rcarriga/nvim-notify",
    lazy = false,
    config = function()
      vim.notify = require("notify")
    end,
  },

  -- Which Key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("config.which-key")
    end,
  },
}