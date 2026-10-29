local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
-- This config is a Nix-built plugin on the pack path (modules/nvim.nix), and lazy resets the
-- runtimepath at setup: keep this config's own folder on it, or its modules (poi, notes)
-- can't be required afterwards.
local self_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))))
require("lazy").setup({
spec = { import = "plugins"},
performance = { rtp = { paths = { self_root } } },
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "gruvbox" } },
checker = {enable = true},
})
