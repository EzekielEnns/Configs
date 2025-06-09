vim.cmd([[
        set listchars=eol:¬,tab:>·,trail:~,extends:>,precedes:<,space:␣
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
        " formatting now effects comments
        set formatoptions-=c

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
        let g:gitblame_enabled = 1
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
vim.g.netrw_bufsettings = "noma nomod nu rnu nobl nowrap ro"
require("myCmp")
require("myLsp")
require("formatters")
require("myTelescope")
require("myWhichkey")
require("nvim-web-devicons").setup({})
require("nvim-treesitter.configs").setup({
	highlight = {
		enable = false,
	},
})
require("gitblame").setup({
	--Note how the `gitblame_` prefix is omitted in `setup`
	enabled = false,
})
--resiser rules
vim.keymap.set("n", "<c-w>r", "<cmd>WinResizerStartResize<cr>", {})
vim.keymap.set("n", "<c-w>f", "<cmd>WinResizerStartFocus<cr>", {})
vim.keymap.set("n", "<c-w>m", "<cmd>WinResizerStartMove<cr>", {})
vim.keymap.set("n", "<c-w>c", "<Plug>(choosewin)", {})

require("Comment").setup()

--used to have highlighting spell check
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		vim.cmd("TSEnable highlight")
	end,
})

vim.api.nvim_set_keymap("n", "<c-h>", "<cmd>TmuxNavigateLeft<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<c-j>", "<cmd>TmuxNavigateDown<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<c-k>", "<cmd>TmuxNavigateUp<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<c-;>", "<cmd>TmuxNavigateRight<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<c-\\>", "<cmd>TmuxNavigatePrevious<cr>", { noremap = true, silent = true })

require("fidget").setup({})
require("go").setup()

vim.env.ESLINT_D_PPID = vim.fn.getpid()
require("lint").linters_by_ft = {
	javascript = { "eslint_d" },
	typescript = { "eslint_d" },
}
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
	callback = function()
		-- try_lint without arguments runs the linters defined in `linters_by_ft`
		-- for the current filetype
		require("lint").try_lint()
		require("lint").try_lint("codespell")
	end,
})

-- ai??
require("avante_lib").load()
require("avante").setup()
-- views can only be fully collapsed with the global statusline
vim.opt.laststatus = 3
vim.notify = require("notify")
-- cmd omg
require("noice").setup({
	health = {
		checker = true, -- Disable if you don't want health checks to run
	},
	views = {
		cmdline_popup = {
			position = {
				row = "90%",
				col = "50%",
			},
			size = {
				width = 60,
				height = "auto",
			},
			border = {
				style = "rounded",
			},
			win_options = {
				winhighlight = { Normal = "Normal", FloatBorder = "FloatBorder" },
			},
		},
	},
	lsp = {
		-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
		override = {
			["vim.lsp.util.convert_input_to_markdown_lines"] = true,
			["vim.lsp.util.stylize_markdown"] = true,
			["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
		},
	},
	-- you can enable a preset for easier configuration
	presets = {
		bottom_search = true, -- use a classic bottom cmdline for search
		command_palette = true, -- position the cmdline and popupmenu together
		long_message_to_split = true, -- long messages will be sent to a split
		inc_rename = false, -- enables an input dialog for inc-rename.nvim
		lsp_doc_border = false, -- add a border to hover docs and signature help
	},
})
