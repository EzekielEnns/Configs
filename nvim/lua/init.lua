-- Basic vim settings using vim.opt
vim.opt.listchars = { eol = "¬", tab = ">·", trail = "~", extends = ">", precedes = "<", space = "␣" }
vim.opt.autoread = true
vim.opt.encoding = "UTF-8"
vim.opt.background = "dark"
vim.opt.termguicolors = true
vim.opt.guicursor = ""
vim.opt.cmdheight = 1

-- Utils and special features
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.mouse = ""
vim.opt.updatetime = 100
vim.opt.hidden = true
vim.opt.errorbells = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = vim.fn.expand("~/.vim/undodir")
vim.opt.undofile = true
vim.opt.shortmess:append("c")

-- Columns and numbers
vim.opt.wrap = false
vim.opt.signcolumn = "yes"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.ruler = true
vim.opt.scrolloff = 13
vim.opt.colorcolumn = "100"

-- Indenting
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.confirm = true
vim.opt.formatoptions:remove("c")

-- Searching
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- Spell checking
vim.opt.spell = true
vim.opt.spelllang = "en_ca"
vim.opt.spelloptions = "camel"

-- Autocmds and functions that need vim.cmd
vim.api.nvim_create_autocmd("CursorHold", {
	callback = function()
		vim.cmd("silent! checktime")
	end,
})

-- Highlights
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		vim.cmd("highlight WinSeparator ctermbg=none guifg=bg")
		vim.cmd("highlight LineNr guifg=white")
	end,
})

local function git_branch()
	local filepath = vim.api.nvim_buf_get_name(0)
	if filepath == "" or vim.bo.buftype ~= "" then
		-- buffer isn't a real file, return empty
		return " - "
	end

	local dir = vim.fn.fnamemodify(filepath, ":h")
	local cmd = { "git", "-C", dir, "branch", "--show-current" }
	local result = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		-- git command failed (not a repo)
		return "no git"
	end

	return vim.fn.trim(result)
end

-- update branch name on buffer enter safely
vim.api.nvim_create_augroup("GitBranch", { clear = true })
vim.api.nvim_create_autocmd("BufEnter", {
	group = "GitBranch",
	callback = function()
		vim.b.git_branch = git_branch()
	end,
})

_G.mode_indicator = function()
	local modes = {
		["n"] = "NORMAL",
		["no"] = "NORMAL·OPERATOR",
		["v"] = "VISUAL",
		["V"] = "V·LINE",
		["\22"] = "V·BLOCK",
		["s"] = "SELECT",
		["S"] = "S·LINE",
		["\19"] = "S·BLOCK",
		["i"] = "INSERT",
		["R"] = "REPLACE",
		["Rv"] = "V·REPLACE",
		["c"] = "COMMAND",
		["cv"] = "VIM·EX",
		["ce"] = "EX",
		["r"] = "PROMPT",
		["rm"] = "MORE",
		["r?"] = "CONFIRM",
		["!"] = "SHELL",
		["t"] = "TERMINAL",
	}
	local current_mode = vim.api.nvim_get_mode().mode
	return modes[current_mode] or "UNKNOWN"
end

vim.o.statusline = table.concat({
	"%#PmenuSel# ",
	"%{v:lua.mode_indicator()} ",
	"%#LineNr#",
	" %f %=",
	"%y [%l:%c]",
})
vim.opt.statusline:append(" %t%y~(%{b:git_branch})")
vim.opt.showmode = true

-- Global variables
vim.g.gitblame_enabled = 0
vim.g.choosewin_overlay_enable = 1

vim.g.netrw_bufsettings = "noma nomod nu rnu nobl nowrap ro"

-- Line movement keybinds
vim.keymap.set("n", "<M-h>", ":m-2<CR>==", { noremap = true, silent = true })
vim.keymap.set("n", "<M-j>", ":m+1<CR>==", { noremap = true, silent = true })
vim.keymap.set("x", "<M-h>", ":m'<-2<CR>gv=gv", { noremap = true, silent = true })
vim.keymap.set("x", "<M-j>", ":m'>+1<CR>gv=gv", { noremap = true, silent = true })

-- Global statusline
vim.opt.laststatus = 3

-- Window movement keybinds
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to bottom window" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to top window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

require("config.lazy")
-- require("lazy").setup({
-- 	{
-- 		"nvim-treesitter/nvim-treesitter",
-- 		build = ":TSUpdate",
-- 		config = function()
-- 			local configs = require("nvim-treesitter.configs")
--
-- 			configs.setup({
-- 				ensure_installed = {
-- 					"c",
-- 					"lua",
-- 					"vim",
-- 					"vimdoc",
-- 					"query",
-- 					"elixir",
-- 					"heex",
-- 					"javascript",
-- 					"html",
-- 					"go",
-- 					"python",
-- 					"rust",
-- 					"json",
-- 					"typescript",
-- 					"css",
-- 					"bash",
-- 					"markdown",
-- 					"yaml",
-- 					"toml",
-- 				},
-- 				sync_install = false,
-- 				highlight = { enable = true },
-- 				indent = { enable = true },
-- 			})
-- 		end,
-- 	},
-- })
-- transparency
vim.api.nvim_set_hl(0, "Normal", { bg = "none", ctermbg = "none" })
vim.api.nvim_set_hl(0, "NonText", { bg = "none", ctermbg = "none" })

vim.api.nvim_create_autocmd({ "ColorScheme" }, {
	pattern = "*",
	callback = function()
		vim.api.nvim_set_hl(0, "Normal", { bg = "none", ctermbg = "none" })
		vim.api.nvim_set_hl(0, "NonText", { bg = "none", ctermbg = "none" })
	end,
})
