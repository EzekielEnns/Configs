--MAPING
vim.g.mapleader    = " "
local wk           = require("which-key")
local leader_binds = {
    ["f"] = { "<cmd>Telescope find_files<CR>", "find files" },
    ["b"] = { "<cmd>Telescope buffers<CR>", "find buffers" },
    ["/"] = { "<cmd>Telescope live_grep<CR>", "find text" },
    ["d"] = { "<cmd>Telescope diagnostics<CR>", "look through diag" },
    ["s"] = { "<cmd>Telescope lsp_document_symbols<CR>", "find symbol" },
    ["w"] = { "<cmd>Telescope lsp_workspace_symbols<CR>", "find symbol workspace" },
    ["cd"] = { "<cmd>:lua folder_finder()<cr>", "find Directory" },
    ["ev"] = { "<cmd>:Vex!<cr>", "Explorer" },
    ["es"] = { "<cmd>:Sex!<cr>", "Explorer" },
    ["ee"] = { "<cmd>:Exp!<cr>", "Explorer" },
    ["el"] = { "<cmd>:Lexplore!<cr>", "Explorer" },

    ["h"] = { "<cmd>lua vim.lsp.buf.signature_help()<cr>", "lsp sig help" },
    ["lh"] = { "<cmd>lua vim.lsp.buf.hover()<cr>", "hover" },
    ["lH"] = { "<cmd>lua vim.diagnostic.open_float()<cr>", "diagnostic" },
    ["ls"] = { "<cmd>lua vim.lsp.buf.signature_help()<cr>", "signature" },
    ["la"] = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "code action" },
    ["lf"] = { "<cmd>lua vim.lsp.buf.format({async = true})<cr>", "format" },
    ["lr"] = { "<cmd>lua vim.lsp.buf.references()<cr>", "rename" },
    ["lR"] = { "<cmd>lua vim.lsp.buf.rename()<cr>", "rename" },
    ["ld"] = { "<cmd>lua vim.lsp.buf.declaration()<cr>", "declaration" },
    ["lD"] = { "<cmd>lua vim.lsp.buf.definition()<cr>", "definition" },
    ["li"] = { "<cmd>lua vim.lsp.buf.implementation()<cr>", "implementation" },
    ["lt"] = { "<cmd>lua vim.lsp.buf.type_declaration()<cr>", "type" },
    ["["] = { "<cmd>lua vim.diagnostic.goto_prev()<cr>", "prev" },
    ["]"] = { "<cmd>lua vim.diagnostic.goto_next()<cr>", "next" },


    ["p"] = { '"+p', "find text from clip" },
    ["P"] = { '"+P', "paste from clip" },
    ["y"] = { '"+y', "yank from clip" },
    ["yy"] = { '"+yy', "yank line from clip" },
    ["Y"] = { '"+yg_', "yank line" },
    ["tr"] = { "<cmd>setlocal relativenumber!<CR>", "toggle relative lines" },
    --TODO toggle relative lines
}
wk.register(leader_binds, { prefix = "<leader>" })
wk.register(leader_binds, { prefix = "<leader>", mode = "v" })
