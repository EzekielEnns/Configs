-- Basic vim settings
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
    set formatoptions-=c

    "searching
    set hls
    set incsearch

    set t_Co=256
    set background=dark

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

-- Global statusline
vim.opt.laststatus = 3
require("config.lazy")
