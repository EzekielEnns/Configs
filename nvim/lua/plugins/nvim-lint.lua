return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    vim.env.ESLINT_D_PPID = vim.fn.getpid()

    require("lint").linters_by_ft = {
      javascript = { "eslint_d" },
      typescript = { "eslint_d" },
    }

    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
      callback = function()
        require("lint").try_lint()
        require("lint").try_lint("codespell")
      end,
    })
  end,
}