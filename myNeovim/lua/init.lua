vim.cmd([[
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
        set mouse+=a
        set clipboard=unnamedplus
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
        set nohlsearch
        set incsearch
]])
-- good reffernce https://www.reddit.com/r/neovim/comments/1039iti/minimal_config_with_lazy_treesitter_lspzero/
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git", "--branch=stable", -- latest stable release
        lazypath
    })
end
vim.opt.rtp:prepend(lazypath)
vim.g.mapleader = " " -- Make sure to set `mapleader` before lazy so your mappings are correct

require("lazy").setup({
    -- STYLE
    {
        "kyazdani42/nvim-web-devicons",
        config = function()
            require("nvim-web-devicons").setup({
                override = {
                    zsh = {
                        icon = "",
                        color = "#428850",
                        cterm_color = "65",
                        name = "Zsh"
                    }
                },
                -- globally enable default icons (default to false)
                -- will get overriden by `get_icons` option
                default = true
            })
        end
    }, {
        "goolord/alpha-nvim",
        lazy = true,
        event = "VimEnter",
        dependencies = {"kyazdani42/nvim-web-devicons"},
        config = function()
            local status_ok, alpha = pcall(require, "alpha")
            if not status_ok then return end

            local dashboard = require("alpha.themes.dashboard")
            dashboard.section.header.val = {
                [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⡷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
                [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⡿⠋⠈⠻⣮⣳⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
                [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣴⣾⡿⠋⠀⠀⠀⠀⠙⣿⣿⣤⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
                [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣶⣿⡿⠟⠛⠉⠀⠀⠀⠀⠀⠀⠀⠈⠛⠛⠿⠿⣿⣷⣶⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
                [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⣾⡿⠟⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠛⠻⠿⣿⣶⣦⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
                [[⠀⠀⠀⣀⣠⣤⣤⣀⡀⠀⠀⣀⣴⣿⡿⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⠿⣿⣷⣦⣄⡀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣤⣄⠀⠀]],
                [[⢀⣤⣾⡿⠟⠛⠛⢿⣿⣶⣾⣿⠟⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⠿⣿⣷⣦⣀⣀⣤⣶⣿⡿⠿⢿⣿⡀⠀]],
                [[⣿⣿⠏⠀⢰⡆⠀⠀⠉⢿⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⢿⡿⠟⠋⠁⠀⠀⢸⣿⠇⠀]],
                [[⣿⡟⠀⣀⠈⣀⡀⠒⠃⠀⠙⣿⡆⠀⠀⠀⠀⠀⠀⠀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⠇⠀]],
                [[⣿⡇⠀⠛⢠⡋⢙⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⠀⠀]],
                [[⣿⣧⠀⠀⠀⠓⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠛⠋⠀⠀⢸⣧⣤⣤⣶⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣿⡿⠀⠀]],
                [[⣿⣿⣤⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠻⣷⣶⣶⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⠁⠀⠀]],
                [[⠈⠛⠻⠿⢿⣿⣷⣶⣦⣤⣄⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⡏⠀⠀⠀]],
                [[⠀⠀⠀⠀⠀⠀⠀⠉⠙⠛⠻⠿⢿⣿⣷⣶⣦⣤⣄⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠿⠛⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢿⣿⡄⠀⠀]],
                [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠙⠛⠻⠿⢿⣿⣷⣶⣦⣤⣄⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣿⡄⠀]],
                [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠛⠛⠿⠿⣿⣷⣶⣶⣤⣤⣀⡀⠀⠀⠀⢀⣴⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⡿⣄]],
                [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠛⠛⠿⠿⣿⣷⣶⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣹]],
                [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⠀⠀⠀⠀⠀⠀⢸⣧]],
                [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣿⣆⠀⠀⠀⠀⠀⠀⢀⣀⣠⣤⣶⣾⣿⣿⣿⣿⣤⣄⣀⡀⠀⠀⠀⣿]],
                [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⢿⣻⣷⣶⣾⣿⣿⡿⢯⣛⣛⡋⠁⠀⠀⠉⠙⠛⠛⠿⣿⣿⡷⣶⣿]]
            }

            dashboard.section.buttons.val = {
                dashboard.button("f", "  Find file",
                                 ":Telescope find_files <CR>"),
                dashboard.button("e", "  New file",
                                 ":ene <BAR> startinsert <CR>"),
                dashboard.button("r", "  Recently used files",
                                 ":Telescope oldfiles <CR>"),
                dashboard.button("t", "  Find text",
                                 ":Telescope live_grep <CR>"),
                dashboard.button("c", "  Configuration",
                                 ":e ~/.config/nvim/init.lua<CR>"),
                dashboard.button("q", "  Quit Neovim", ":qa<CR>")
            }

            local function footer()
                return "Don't Stop Until You are Proud..."
            end

            dashboard.section.footer.val = footer()

            dashboard.section.footer.opts.hl = "Type"
            dashboard.section.header.opts.hl = "Include"
            dashboard.section.buttons.opts.hl = "Keyword"

            dashboard.opts.opts.noautocmd = true
            alpha.setup(dashboard.opts)
        end
    }, "MunifTanjim/nui.nvim", {
        "Th3Whit3Wolf/one-nvim",
        config = function()
            vim.opt.termguicolors = true
            -- vim.opt.background ="light"
            vim.cmd.colorscheme("one-nvim")
        end
    }, {
        "nvim-lualine/lualine.nvim",
        dependencies = {"kyazdani42/nvim-web-devicons"},
        config = function()
            require("lualine").setup({
                options = {
                    icons_enabled = true,
                    theme = "auto",
                    component_separators = {left = "", right = ""},
                    section_separators = {left = "", right = ""},
                    disabled_filetypes = {statusline = {}, winbar = {}},
                    ignore_focus = {},
                    always_divide_middle = true,
                    globalstatus = false,
                    refresh = {statusline = 1000, tabline = 1000, winbar = 1000}
                },
                sections = {
                    lualine_a = {"mode"},
                    lualine_b = {"branch", "diff", "diagnostics"},
                    lualine_c = {"filename"},
                    lualine_x = {"encoding", "fileformat", "filetype"},
                    lualine_y = {"progress"},
                    lualine_z = {"location"}
                },
                inactive_sections = {
                    lualine_a = {},
                    lualine_b = {},
                    lualine_c = {"filename"},
                    lualine_x = {"location"},
                    lualine_y = {},
                    lualine_z = {}
                },
                tabline = {},
                winbar = {},
                inactive_winbar = {},
                extensions = {}
            })
        end
    }, -- EDITOR NEEDS
    {
        "vinnymeller/swagger-preview.nvim",
        opts = {port = 8000, host = "localhost"}
    }, {
        "nvim-neo-tree/neo-tree.nvim",
        lazy = false,
        dependencies = {"nvim-lua/plenary.nvim", "kyazdani42/nvim-web-devicons"},
        config = function()
            require("neo-tree").setup({
                close_if_last_window = false,
                enable_git_status = true,
                enable_diagnostics = true
            })
        end
    }, {
        "jay-babu/mason-null-ls.nvim",
        event = {"BufReadPre", "BufNewFile"},
        dependencies = {
            "williamboman/mason.nvim", "jose-elias-alvarez/null-ls.nvim"
        }
    }, {
        "folke/trouble.nvim",
        lazy = false,
        dependencies = {"kyazdani42/nvim-web-devicons", "folke/lsp-colors.nvim"}
    }, {"sbdchd/neoformat", lazy = false}, {
        "VonHeikemen/lsp-zero.nvim",
        dependencies = {
            "neovim/nvim-lspconfig", "hrsh7th/nvim-cmp", "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path", "saadparwaiz1/cmp_luasnip",
            "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-nvim-lua", "L3MON4D3/LuaSnip",
            "rafamadriz/friendly-snippets"
        },
        config = function()
            local lsp = require("lsp-zero")
            lsp.preset("recommended")
            lsp.on_attach(function(client, bufnr)
                lsp.default_keymaps({buffer = bufnr})
            end)
            lsp.nvim_workspace()

            -- listing servers
            -- lsp.setup_servers({ "yamlfmt", "yamllint",
            --     "sql-formatter" })
            --
            vim.lsp.set_log_level("debug")
            require'lspconfig'.astro.setup {
                -- reqiores pnpm i -D @astrojs/language-server typescript
                cmd = {"pnpm", "astro-ls", "--stdio"}
            }
            require'lspconfig'.clangd.setup{}
            require'lspconfig'.statix.setup {}
            require'lspconfig'.marksman.setup {}
            require'lspconfig'.tsserver.setup {}
            require'lspconfig'.eslint.setup {}
            require'lspconfig'.gopls.setup {}
            require'lspconfig'.rust_analyzer.setup {}
            require'lspconfig'.terraformls.setup {}
            vim.api.nvim_create_autocmd({"BufWritePre"}, {
                pattern = {"*.tf", "*.tfvars"},
                callback = function() vim.lsp.buf.format() end
            })
            lsp.setup()
            vim.diagnostic.config({virtual_text = true})
            local cmp = require("cmp")
            cmp.setup({
                sources = {
                    {name = 'path'}, {name = 'nvim_lsp', keyword_length = 1},
                    {name = 'buffer', keyword_length = 3},
                    {name = 'luasnip', keyword_length = 2}
                },
                formatting = {
                    fields = {'menu', 'abbr', 'kind'},
                    format = function(entry, item)
                        local menu_icon = {
                            nvim_lsp = 'λ',
                            luasnip = '⋗',
                            buffer = 'Ω',
                            path = '🖫'
                        }

                        item.menu = menu_icon[entry.source.name]
                        return item
                    end
                },
                mapping = {
                    ["<CR>"] = cmp.mapping.confirm({select = false}),
                    ["<C-l>"] = cmp.mapping.complete()
                }
            })
            -- local null_ls = require("null-ls")
            --
            -- null_ls.setup({
            --     sources = {
            --         -- Here you can add tools not supported by mason.nvim
            --         -- make sure the source name is supported by null-ls
            --         -- https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md
            --     },
            -- })
            -- -- See mason-null-ls.nvim's documentation for more details:
            -- -- https://github.com/jay-babu/mason-null-ls.nvim#setup
            -- require("mason-null-ls").setup({
            --     ensure_installed = nil,
            --     automatic_installation = true, -- You can still set this to `true`
            --     handlers = {},
            -- })

            -- vim.cmd([[autocmd BufWritePre * LspZeroFormat]])
        end
    }, {"LhKipp/nvim-nu", config = function() require'nu'.setup {} end}, {
        -- REMEBER to do TSInstall for new langs, also note it binary tree-sitter-cli
        "nvim-treesitter/nvim-treesitter",
        dependencies = {"LhKipp/nvim-nu"},
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = {
                    "c", "lua", "rust", "terraform", "nu", "dockerfile", "diff",
                    "git_rebase", "gitignore", "gitcommit", "go", "gomod",
                    "json", "sql", "typescript", "tsx", "html", "css", "tsx","make",
                    "astro"
                },
                highlight = {enable = true},
                with_sync = true
            })
        end
    }, -- MARKDOWN
    {
        'img-paste-devs/img-paste.vim',
        config = function()
            vim.cmd([[
                autocmd FileType markdown nmap <buffer><silent> <leader>p :call mdip#MarkdownClipboardImage()<CR>
            ]])
        end
    }, -- EDITOR UTILS
    {
        "terrortylor/nvim-comment",
        lazy = false,
        keys = {{"<leader>/", ":'<,'>CommentToggle<CR>gv<esc>j", mode = {"v"}}},
        config = function() require("nvim_comment").setup() end
    }, {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.1",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-telescope/telescope-live-grep-args.nvim"
        },
        config = function()
            require("telescope").load_extension("live_grep_args")
        end
    }, {"windwp/nvim-autopairs", event = "InsertEnter", opts = {}}, {
        "folke/which-key.nvim",
        lazy = false,
        config = function()
            local which_key = require("which-key")
            local setup = {
                plugins = {
                    marks = true, -- shows a list of your marks on ' and `
                    presets = {
                        windows = true, -- default bindings on <c-w>
                        nav = true, -- misc bindings to work with windows
                        z = true, -- bindings for folds, spelling and others prefixed with z
                        g = true -- bindings for prefixed with g
                    }
                },
                layout = {
                    height = {min = 4, max = 25}, -- min and max height of the columns
                    width = {min = 20, max = 50}, -- min and max width of the columns
                    spacing = 3, -- spacing between columns
                    align = "left" -- align columns left, center or right
                },
                ignore_missing = true, -- enable this to hide mappings for which you didn't specify a label
                hidden = {
                    "<silent>", "<cmd>", "<Cmd>", "<CR>", "call", "lua", "^:",
                    "^ "
                }, -- hide mapping boilerplate
                show_help = true, -- show help message on the command line when the popup is visible
                triggers = "auto", -- automatically setup triggers
                triggers_blacklist = {i = {"j", "k"}, v = {"j", "k"}}
            }

            local opts = {
                mode = "n", -- NORMAL mode
                prefix = "<leader>",
                buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
                silent = true, -- use `silent` when creating keymaps
                noremap = true, -- use `noremap` when creating keymaps
                nowait = true -- use `nowait` when creating keymaps
            }

            local mappings = {
                ["k"] = {"<cmd>bdelete<CR>", "Kill Buffer"}, -- Close current file
                ["p"] = {"<cmd>Lazy<CR>", "Plugin Manager"}, -- Invoking plugin manager
                ["q"] = {"<cmd>qa<CR>", "Quit"}, -- Quit Neovim after saving the file
                ["w"] = {"<cmd>w!<CR>", "Save"}, -- Save current file
                ["r"] = {"<cmd>set relativenumber!<CR>", "Toggle relative"}, -- Save current file
                ["a"] = {"<cmd>Alpha<CR>", "Menu"},
                g = {
                    name = "goto",
                    d = {
                        "<cmd>lua vim.lsp.buf.definition()<cr>",
                        "jump to definition"
                    },
                    D = {
                        "<cmd>lua vim.lsp.buf.declaration()<cr>",
                        "jump to delcation"
                    },
                    i = {
                        "<cmd>lua vim.lsp.buf.implementation()<cr>",
                        "list all implementation"
                    },
                    o = {
                        "<cmd>lua vim.lsp.buf.type_definition()<cr>",
                        "jump to type def"
                    },
                    r = {"<cmd>lua vim.lsp.buf.references()<cr>", "references"},
                    s = {
                        "<cmd>lua vim.lsp.buf.signature_help()<cr>",
                        "display signature info"
                    },
                    l = {
                        "<cmd>lua vim.diagnostic.open_float()<cr>",
                        "float diagnostic"
                    }
                },
                e = {
                    name = "Explorer",
                    e = {
                        "<cmd>Neotree  filesystem toggle float<CR>", "File exp"
                    },
                    b = {"<cmd>Neotree  buffers toggle float<CR>", "Buffer exp"},
                    g = {"<cmd>Neotree  git_status toggle float<CR>", "Git exp"}
                },
                f = {
                    name = "Finder",
                    b = {"<cmd>Telescope buffers<CR>","buffers"},
                    w = {
                        "<cmd>lua require('telescope.builtin').live_grep({grep_open_files=true})<CR>",
                        "Word in buffers"
                    },
                    p = {"<cmd>Telescope live_grep<CR>", "Word in project"},
                    f = {"<cmd>Telescope find_files<CR>", "files"}
                },
                l = {
                    -- https://neovim.io/doc/user/lsp.html
                    name = "LSP",
                    a = {"<cmd>lua vim.lsp.buf.code_action<cr>", "Code action"},
                    i = {"<cmd>LSPInfo<cr>", "Info"},
                    l = {
                        "<cmd>lua vim.lsp.codelens.run()<cr>",
                        "Codelens Actions"
                    },
                    r = {"<cmd>Telescope lsp_references<cr>", "Find reffernce"},
                    s = {
                        "<cmd>Telescope lsp_document_symbols<cr>",
                        "Document Symbols"
                    },
                    S = {
                        "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>",
                        "Workspace Symbols"
                    }
                    -- TODO implement refactor options
                }
            }

            which_key.setup(setup)
            which_key.register(mappings, opts)
        end
    }
    --[[
        https://medium.com/@shaikzahid0713/the-neovim-series-32163eb1f5d0
        https://astronvim.com/Configuration/plugin_defaults
        TODO add git integrations
        TODO add other utils undo tree, manip, indentline,
        TODO add faster escape  https://github.com/max397574/better-escape.nvim
    ]]
    --
})

-- adding high constra7t to number lines TODO make pretty
vim.cmd("hi LineNr guibg=#000000 guifg=#ffffff")
-- fix for https://github.com/nvim-treesitter/nvim-treesitter/issues/2293
local treesitter_migrate = function()
    local map = {
        ["annotation"] = "TSAnnotation",

        ["attribute"] = "TSAttribute",

        ["boolean"] = "TSBoolean",

        ["character"] = "TSCharacter",
        ["character.special"] = "TSCharacterSpecial",

        ["comment"] = "TSComment",

        ["conditional"] = "TSConditional",

        ["constant"] = "TSConstant",
        ["constant.builtin"] = "TSConstBuiltin",
        ["constant.macro"] = "TSConstMacro",

        ["constructor"] = "TSConstructor",

        ["debug"] = "TSDebug",
        ["define"] = "TSDefine",

        ["error"] = "TSError",
        ["exception"] = "TSException",

        ["field"] = "TSField",

        ["float"] = "TSFloat",

        ["function"] = "TSFunction",
        ["function.call"] = "TSFunctionCall",
        ["function.builtin"] = "TSFuncBuiltin",
        ["function.macro"] = "TSFuncMacro",

        ["include"] = "TSInclude",

        ["keyword"] = "TSKeyword",
        ["keyword.function"] = "TSKeywordFunction",
        ["keyword.operator"] = "TSKeywordOperator",
        ["keyword.return"] = "TSKeywordReturn",

        ["label"] = "TSLabel",

        ["method"] = "TSMethod",
        ["method.call"] = "TSMethodCall",

        ["namespace"] = "TSNamespace",

        ["none"] = "TSNone",
        ["number"] = "TSNumber",

        ["operator"] = "TSOperator",

        ["parameter"] = "TSParameter",
        ["parameter.reference"] = "TSParameterReference",

        ["preproc"] = "TSPreProc",

        ["property"] = "TSProperty",

        ["punctuation.delimiter"] = "TSPunctDelimiter",
        ["punctuation.bracket"] = "TSPunctBracket",
        ["punctuation.special"] = "TSPunctSpecial",

        ["repeat"] = "TSRepeat",

        ["storageclass"] = "TSStorageClass",

        ["string"] = "TSString",
        ["string.regex"] = "TSStringRegex",
        ["string.escape"] = "TSStringEscape",
        ["string.special"] = "TSStringSpecial",

        ["symbol"] = "TSSymbol",

        ["tag"] = "TSTag",
        ["tag.attribute"] = "TSTagAttribute",
        ["tag.delimiter"] = "TSTagDelimiter",

        ["text"] = "TSText",
        ["text.strong"] = "TSStrong",
        ["text.emphasis"] = "TSEmphasis",
        ["text.underline"] = "TSUnderline",
        ["text.strike"] = "TSStrike",
        ["text.title"] = "TSTitle",
        ["text.literal"] = "TSLiteral",
        ["text.uri"] = "TSURI",
        ["text.math"] = "TSMath",
        ["text.reference"] = "TSTextReference",
        ["text.environment"] = "TSEnvironment",
        ["text.environment.name"] = "TSEnvironmentName",

        ["text.note"] = "TSNote",
        ["text.warning"] = "TSWarning",
        ["text.danger"] = "TSDanger",

        ["todo"] = "TSTodo",

        ["type"] = "TSType",
        ["type.builtin"] = "TSTypeBuiltin",
        ["type.qualifier"] = "TSTypeQualifier",
        ["type.definition"] = "TSTypeDefinition",

        ["variable"] = "TSVariable",
        ["variable.builtin"] = "TSVariableBuiltin"
    }

    for capture, hlgroup in pairs(map) do
        vim.api.nvim_set_hl(0, "@" .. capture, {link = hlgroup, default = true})
    end

    local defaults = {
        TSNone = {default = true},
        TSPunctDelimiter = {link = "Delimiter", default = true},
        TSPunctBracket = {link = "Delimiter", default = true},
        TSPunctSpecial = {link = "Delimiter", default = true},

        TSConstant = {link = "Constant", default = true},
        TSConstBuiltin = {link = "Special", default = true},
        TSConstMacro = {link = "Define", default = true},
        TSString = {link = "String", default = true},
        TSStringRegex = {link = "String", default = true},
        TSStringEscape = {link = "SpecialChar", default = true},
        TSStringSpecial = {link = "SpecialChar", default = true},
        TSCharacter = {link = "Character", default = true},
        TSCharacterSpecial = {link = "SpecialChar", default = true},
        TSNumber = {link = "Number", default = true},
        TSBoolean = {link = "Boolean", default = true},
        TSFloat = {link = "Float", default = true},

        TSFunction = {link = "Function", default = true},
        TSFunctionCall = {link = "TSFunction", default = true},
        TSFuncBuiltin = {link = "Special", default = true},
        TSFuncMacro = {link = "Macro", default = true},
        TSParameter = {link = "Identifier", default = true},
        TSParameterReference = {link = "TSParameter", default = true},
        TSMethod = {link = "Function", default = true},
        TSMethodCall = {link = "TSMethod", default = true},
        TSField = {link = "Identifier", default = true},
        TSProperty = {link = "Identifier", default = true},
        TSConstructor = {link = "Special", default = true},
        TSAnnotation = {link = "PreProc", default = true},
        TSAttribute = {link = "PreProc", default = true},
        TSNamespace = {link = "Include", default = true},
        TSSymbol = {link = "Identifier", default = true},

        TSConditional = {link = "Conditional", default = true},
        TSRepeat = {link = "Repeat", default = true},
        TSLabel = {link = "Label", default = true},
        TSOperator = {link = "Operator", default = true},
        TSKeyword = {link = "Keyword", default = true},
        TSKeywordFunction = {link = "Keyword", default = true},
        TSKeywordOperator = {link = "TSOperator", default = true},
        TSKeywordReturn = {link = "TSKeyword", default = true},
        TSException = {link = "Exception", default = true},
        TSDebug = {link = "Debug", default = true},
        TSDefine = {link = "Define", default = true},
        TSPreProc = {link = "PreProc", default = true},
        TSStorageClass = {link = "StorageClass", default = true},

        TSTodo = {link = "Todo", default = true},

        TSType = {link = "Type", default = true},
        TSTypeBuiltin = {link = "Type", default = true},
        TSTypeQualifier = {link = "Type", default = true},
        TSTypeDefinition = {link = "Typedef", default = true},

        TSInclude = {link = "Include", default = true},

        TSVariableBuiltin = {link = "Special", default = true},

        TSText = {link = "TSNone", default = true},
        TSStrong = {bold = true, default = true},
        TSEmphasis = {italic = true, default = true},
        TSUnderline = {underline = true},
        TSStrike = {strikethrough = true},

        TSMath = {link = "Special", default = true},
        TSTextReference = {link = "Constant", default = true},
        TSEnvironment = {link = "Macro", default = true},
        TSEnvironmentName = {link = "Type", default = true},
        TSTitle = {link = "Title", default = true},
        TSLiteral = {link = "String", default = true},
        TSURI = {link = "Underlined", default = true},

        TSComment = {link = "Comment", default = true},
        TSNote = {link = "SpecialComment", default = true},
        TSWarning = {link = "Todo", default = true},
        TSDanger = {link = "WarningMsg", default = true},

        TSTag = {link = "Label", default = true},
        TSTagDelimiter = {link = "Delimiter", default = true},
        TSTagAttribute = {link = "TSProperty", default = true}
    }

    for group, val in pairs(defaults) do vim.api.nvim_set_hl(0, group, val) end
end
treesitter_migrate()
