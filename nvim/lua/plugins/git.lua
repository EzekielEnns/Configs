return {
  -- Git gutter signs
  {
    "airblade/vim-gitgutter",
    event = { "BufReadPre", "BufNewFile" },
  },

  -- Git blame
  {
    "f-person/git-blame.nvim",
    cmd = { "GitBlameToggle" },
    config = function()
      require("gitblame").setup({
        enabled = false,
      })
    end,
  },
}