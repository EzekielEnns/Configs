return {
  "nvim-treesitter/nvim-treesitter",
  event = { "BufReadPost", "BufNewFile" },
  build = ":TSUpdate",
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects",
  },
  config = function()
    require("nvim-treesitter.configs").setup({
      highlight = {
        enable = true,
      },
      ensure_installed = {
        "lua",
        "javascript",
        "typescript",
        "go",
        "python",
        "rust",
        "html",
        "css",
        "json",
        "yaml",
        "markdown",
        "bash",
      },
      auto_install = true,
    })
  end,
}