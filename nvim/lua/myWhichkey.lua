--MAPING
vim.g.mapleader = " "
local wk = require("which-key")
wk.add({
    {"<leader>f" ,"<cmd>Telescope find_files<CR>", desc= "find files" },
    {"<leader>b", "<cmd>Telescope buffers<CR>",desc= "find buffers" },
    {"<leader>/", "<cmd>Telescope live_grep<CR>",desc= "find text" },
    {"<leader>d", "<cmd>Telescope diagnostics<CR>",desc= "look through diag" },
    {"<leader>ls", "<cmd>Telescope lsp_document_symbols<CR>",desc= "" },
    {"<leader>lw", "<cmd>Telescope lsp_workspace_symbols<CR>",desc= "" },
    {"<leader>lr", "<cmd>Telescope lsp_references<CR>",desc= "" },
    {"<leader>le", "<cmd>Telescope lsp_document_diagnostics<CR>",desc= "" },
    {"<leader>li","<cmd>Telescope lsp_implementations<CR>",desc= "implementation" },

    {"<leader>cd", "<cmd>:lua folder_finder()<cr>",desc= "find Directory" },
    {"<leader>ev", "<cmd>:Vex!<cr>",desc= "Explorer" },
    {"<leader>es", "<cmd>:Sex!<cr>",desc= "Explorer" },
    {"<leader>ee", "<cmd>:Exp!<cr>",desc= "Explorer" },
    {"<leader>el", "<cmd>:Lexplore!<cr>",desc= "Explorer" },
    {"<leader>gb","<cmd>:GitBlameToggle<CR>"},

    {"<leader>h", "<cmd>lua vim.lsp.buf.signature_help()<cr>",desc= "lsp sig help" },
    {"<leader>lh","<cmd>lua vim.lsp.buf.hover()<cr>",desc= "hover" },
    {"<leader>lH","<cmd>lua vim.diagnostic.open_float()<cr>",desc= "diagnostic" },
    {"<leader>ls","<cmd>lua vim.lsp.buf.signature_help()<cr>",desc= "signature" },
    {"<leader>la","<cmd>lua vim.lsp.buf.code_action()<cr>",desc= "code action" },
    --{"<leader>lf","<cmd>lua vim.lsp.buf.format({async = true})<cr>",desc= "format" },
    --{"<leader>lr","<cmd>lua vim.lsp.buf.references()<cr>",desc= "rename" },
    {"<leader>r","<cmd>lua vim.lsp.buf.rename()<cr>",desc= "rename" },
    --{"<leader>ld","<cmd>lua vim.lsp.buf.declaration()<cr>",desc= "declaration" },
    --{"<leader>lD","<cmd>lua vim.lsp.buf.definition()<cr>",desc= "definition" },
    {"<leader>lt","<cmd>Telescope lsp_type_definitions<CR>",desc= "type" },
    { "<leader>]","<cmd>lua vim.diagnostic.goto_prev()<cr>",desc= "prev" },
    { "<leader>[","<cmd>lua vim.diagnostic.goto_next()<cr>",desc= "next" },

    {"<leader>p",'"+p',desc= "find text from clip",mode ={"v","n"} },
    {"<leader>P",'"+P',desc= "paste from clip",mode ={"v","n"} },
    {"<leader>y",'"+y',desc= "yank from clip",mode ={"v","n"} },
    { "<leader>yy",'"+yy',desc= "yank line from clip",mode ={"v","n"}},
    { "<leader>Y",'"+yg_',desc= "yank line",mode ={"v","n"} },
    { "<leader>tr","<cmd>setlocal relativenumber!<CR>",desc= "toggle relative lines",mode ={"v","n"} },
})
-- wk.register(leader_binds, { prefix = "<leader>" })
-- wk.register(leader_binds, { prefix = "<leader>", mode = "v" })
