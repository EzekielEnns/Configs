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
vim.g.netrw_bufsettings = 'noma nomod nu rnu nobl nowrap ro'
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
	enabled = true,
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
