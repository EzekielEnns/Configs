return {
  "ray-x/go.nvim",
  -- pinned: master uses vim.lsp.codelens.enable() (nvim 0.12+ only); this is the last commit that works on 0.11.x
  commit = "76df000467713a55bb011cd273386dd36e7642f0",
  ft = { "go", "gomod" },
  dependencies = {
    "ray-x/guihua.lua",
    "neovim/nvim-lspconfig",
    "nvim-treesitter/nvim-treesitter",
  },
  opts={}
}
