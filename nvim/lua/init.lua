vim.cmd([[
        set autoread                                                                                                                                                                                    
        au CursorHold * silent! checktime
    "colors and cursor
        set encoding=UTF-8
        set background=dark
        set termguicolors
        set guicursor=
        set cmdheight=1
    "utils and special features
        set autoread
        set splitbelow
        set splitright
        "the mouse is evil.... on my laptop
        set mouse=
        set updatetime=100
        set encoding=utf-8
        set hidden
        set noerrorbells
        set noswapfile
        set nobackup
        set undodir=~/.vim/undodir
        set undofile
        set shortmess+=c

    "columns and numbers
        set nowrap
        set signcolumn=yes
        set number
        set relativenumber
        set ruler
        set scrolloff=13
        set colorcolumn=100

    "indenting
        set autoindent
        set smartindent
        set tabstop=4 softtabstop=4
        set shiftwidth=4
        set expandtab
        set confirm

    "searching
        set hls
        set incsearch

        set t_Co=256
        set background=dark
        colorscheme gruvbox

        let g:winresizer_enable = 1
    "make WinSeparator invisible
        highlight WinSeparator ctermbg=none guifg=bg   
        highlight LineNr guifg=white

        set spell spelllang=en_ca spo=camel
        set syntax=ON   
        let g:gitblame_enabled = 0
        let g:choosewin_overlay_enable = 1
        "status 
        function Gitbranch()
            return trim(system("git -C " . expand("%:h") . " branch --show-current 2>/dev/null"))
            endfunction

            augroup Gitget
            autocmd!
            autocmd BufEnter * let b:git_branch = Gitbranch()
        augroup END

        set statusline+=\ %t%y\~(%{b:git_branch})
]])
require("nvim-web-devicons").setup({})
require 'nvim-treesitter.configs'.setup {
    highlight = {
        enable = false,
    },
}
require('gitblame').setup {
     --Note how the `gitblame_` prefix is omitted in `setup`
    enabled = true,
}
--resiser rules
vim.keymap.set('n', '<c-w>r', '<cmd>WinResizerStartResize<cr>', {});
vim.keymap.set('n', '<c-w>f', '<cmd>WinResizerStartFocus<cr>', {});
vim.keymap.set('n', '<c-w>m', '<cmd>WinResizerStartMove<cr>', {});
vim.keymap.set('n', '<c-w>c', '<Plug>(choosewin)', {});

--https://nuxsh.is-a.dev/blog/custom-nvim-statusline.html
local cmp = require('cmp')
local cmp_autopairs = require('nvim-autopairs.completion.cmp')
cmp.event:on(
    'confirm_done',
    cmp_autopairs.on_confirm_done()
)
cmp.setup({
    sources = {
        { name = 'path' },
        { name = 'nvim_lsp', keyword_length = 1 },
        { name = 'buffer',   keyword_length = 3 },
        --{ name = 'vsnip',    keyword_length = 2 },
        { name = 'luasnip' },
        {
            name = 'spell',
            option = {
                keep_all_entries = false,
                enable_in_context = function()
                    return true
                end,
            },
        },
    },
    formatting = {
        fields = { 'menu', 'abbr', 'kind' },
        format = function(entry, item)
            local menu_icon = {
                nvim_lsp = 'λ',
                luasnip= '⋗',
                buffer = 'Ω',
                path = '🖫'
            }

            item.menu = menu_icon[entry.source.name]
            return item
        end
    },

    mapping = cmp.mapping.preset.insert({
        ["<TAB>"] = cmp.mapping.select_next_item(),
        ["<S-TAB>"] = cmp.mapping.select_prev_item(),
        --["<>"] = cmp.mapping.select_next_item(),
        ["<CR>"] = cmp.mapping.confirm({ select = false }),
        ["<C-l>"] = cmp.mapping.complete()
    }),
    snippet = {
        expand = function(args)
            require 'luasnip'.lsp_expand(args.body)
            --vim.fn["vsnip#anonymous"](args.body)
        end
    },
    window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
    },
})
-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline({ '/', '?' }, {
    mapping = cmp.mapping.preset.cmdline(),
    sources = {
        { name = 'buffer' }
    }
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(':', {
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources({
        { name = 'path' }
    }, {
        { name = 'cmdline' }
    }),
    matching = { disallow_symbol_nonprefix_matching = false }
})
vim.diagnostic.config({ virtual_text = true })
vim.lsp.set_log_level("off")
--lsp
require('trouble').setup({})
local lspconfig = require('lspconfig')
local lsp_defaults = lspconfig.util.default_config
local cap = vim.tbl_deep_extend('force', lsp_defaults.capabilities,
    require('cmp_nvim_lsp').default_capabilities())
lsp_defaults.capabilities = cap
vim.api.nvim_create_autocmd('LspAttach', {
    desc = 'LSP actions',
    callback = function(event)
        local opts = { buffer = event.buf }
        vim.keymap.set('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<cr>', opts)
    end
})

require 'lspconfig'.astro.setup {
    -- requires pnpm i -D @astrojs/language-server typescript
    cmd = { "pnpm", "astro-ls", "--stdio" }
}
require 'lspconfig'.tailwindcss.setup {
    -- requires pnpm i -D @astrojs/language-server typescript
    cmd = { "pnpm", "tailwindcss-language-server", "--stdio" }
}
require 'lspconfig'.ltex.setup {}
require 'lspconfig'.hls.setup {}
require 'lspconfig'.texlab.setup {}
require 'lspconfig'.clangd.setup {}
require 'lspconfig'.nil_ls.setup {}
require 'lspconfig'.marksman.setup {}
require("typescript-tools").setup {
  settings = {
    tsserver_file_preferences = {
      includeInlayParameterNameHints = "all",
      includeCompletionsForModuleExports = true,
      quotePreference = "auto",
      importModuleSpecifierPreference= "non-relative",
      updateImportsOnFileMove= "always",
      importModuleSpecifierEnding="minimal"
    },
    separate_diagnostic_server = true,
    publish_diagnostic_on = "change",
    expose_as_code_action = {},
    tsserver_max_memory = "auto",
    tsserver_locale = "en",
    complete_function_calls = false,
    include_completions_with_insert_text = true,
    code_lens = "off",
    disable_member_code_lens = false,
    jsx_close_tag = {
        enable = true,
        filetypes = { "javascriptreact", "typescriptreact" },
    }
  },
}
require 'lspconfig'.kotlin_language_server.setup {}
require 'lspconfig'.eslint.setup {}
require 'lspconfig'.gopls.setup {
    settings = {
        gopls = {
            completeUnimported = true,
            usePlaceholders = true
        }
    }
}
require 'lspconfig'.pylsp.setup {}
require 'lspconfig'.ruff_lsp.setup {}
require 'lspconfig'.terraformls.setup {}
require 'lspconfig'.lua_ls.setup {}
require 'lspconfig'.lemminx.setup {}
require 'lspconfig'.svelte.setup {}
require "lsp_signature".setup({
    bind = true, -- This is mandatory, otherwise border config won't get registered.
    hint_enable = true,
    toggle_key = "<M-f>",
    floating_window = false,
    handler_opts = {
        border = "shadow"
    }
})
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    pattern = { "*.tf", "*.tfvars" },
    callback = function() vim.lsp.buf.format() end
})

vim.g.rustaceanvim = {
  -- Plugin configuration
  tools = {
  },
  -- LSP configuration
  server = {
    on_attach = function(client, bufnr)
      -- you can also put keymaps in here
    end,
    default_settings = {
      -- rust-analyzer language server configuration
      ['rust-analyzer'] = {
      },
    },
  },
  -- DAP configuration
  dap = {
  },
}

--CMP
--require("luasnip.loaders.from_vscode").lazy_load { paths = { "~/.config/snippets" } }
-- require("scissors").setup ({
--     snippetDir = "~/.config/snippets",
-- })
vim.keymap.set("n", "<leader>se", function() require("scissors").editSnippet() end)
-- When used in visual mode prefills the selection as body.
vim.keymap.set({ "n", "x" }, "<leader>sa", function() require("scissors").addNewSnippet() end)

--require'telescope'.load_extension('project')
require('telescope').setup {
    defaults = {
        -- Default configuration for telescope goes here:
        -- config_key = value,
        pickers = {
            buffer = {
                mappings = {
                    n = {
                        ['<c-c>'] = require('telescope.actions').delete_buffer
                    }, -- n
                    i = {
                        ['<c-c>'] = require('telescope.actions').delete_buffer
                    } -- i
                }
            }
        },
        mappings = {
        } -- mappings
    },    -- defaults
    ...
}         -- telescope setup
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local dirs = vim.split(vim.fn.glob(vim.fn.getcwd() .. "/*/"), '\n', { trimemtpy = true })
table.insert(dirs, vim.fn.getcwd())
local folders      = function(opts)
    opts = opts or {}
    pickers.new(opts, {
        prompt_title = "Pick Directory",
        finder = finders.new_table {
            results = dirs
        },
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                print(vim.inspect(selection))
                --vim.api.nvim_put({ selection[1] }, "", false, true)
                vim.api.nvim_set_current_dir(selection[1])
            end)
            return true
        end
    }):find()
end

-- to execute the function
_G.folder_finder   = folders
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
require('Comment').setup()
--TODO add formatters
require("formatter").setup {}
require('nvim-autopairs').setup({
    disable_filetype = { "TelescopePrompt", "vim" },
})

--used to have highlighting spell check
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
        vim.cmd('TSEnable highlight')
	end,
})

vim.api.nvim_set_keymap('n', '<c-h>', '<cmd>TmuxNavigateLeft<cr>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<c-j>', '<cmd>TmuxNavigateDown<cr>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<c-k>', '<cmd>TmuxNavigateUp<cr>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<c-;>', '<cmd>TmuxNavigateRight<cr>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<c-\\>', '<cmd>TmuxNavigatePrevious<cr>', { noremap = true, silent = true })

require("fidget").setup { }
require('go').setup()
