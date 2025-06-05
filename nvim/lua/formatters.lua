vim.g.neoformat_enabled_typescript = { 'prettierd' }
vim.g.neoformat_enabled_go = { 'goimports', "gofumpt" }
vim.g.neoformat_enabled_lua = { 'stylua' }
vim.g.neoformat_try_node_exe = 1
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.js", "*.ts", "*.jsx", "*.tsx","*.nix","*.go" },
  command = "Neoformat"
})

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.ts",  "*.tsx", },
  command = "TSToolsRemoveUnusedImports"
})
