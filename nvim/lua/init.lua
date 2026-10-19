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

-- Go tools on macOS are `go install`ed into ~/go/bin (see darwin/home.nix).
-- home-manager puts that on PATH for new login shells, but a terminal that
-- predates the rebuild (or an app-launched nvim) won't have it, so add it here.
for _, dir in ipairs({ vim.env.HOME .. "/go/bin", "/opt/homebrew/bin" }) do
	if vim.uv.fs_stat(dir) and not (":" .. vim.env.PATH .. ":"):find(":" .. dir .. ":", 1, true) then
		vim.env.PATH = dir .. ":" .. vim.env.PATH
	end
end

-- auto-detect uv-managed .venv and export VIRTUAL_ENV so basedpyright/ruff pick it up
local function detect_uv_venv()
	local found = vim.fs.find(".venv", {
		upward = true,
		type = "directory",
		path = vim.fn.getcwd(),
		stop = vim.uv.os_homedir(),
	})[1]
	if not found then
		return
	end
	local python = found .. "/bin/python"
	if vim.uv.fs_stat(python) then
		vim.env.VIRTUAL_ENV = found
		vim.env.PATH = found .. "/bin:" .. vim.env.PATH
		vim.g.python3_host_prog = python
	end
end

vim.api.nvim_create_augroup("UvVenv", { clear = true })
vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
	group = "UvVenv",
	callback = detect_uv_venv,
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
vim.opt.statusline:append(" %t%y~(%{get(b:,'git_branch','')})")
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

-- Spanner DDL files are just SQL as far as highlighting goes.
vim.filetype.add({ extension = { ddl = "sql" } })

require("config.lazy")

-- view_toggle: flip the current buffer between raw text and its rendered view,
-- choosing the renderer from the filetype. csv/tsv start rendered (a raw CSV is
-- the unreadable one), markdown starts raw, so the first press means different
-- directions in each -- which is the point of one key rather than two.
local view_commands = {
	csv = "CsvViewToggle",
	tsv = "CsvViewToggle",
	markdown = "RenderMarkdown buf_toggle",
}

_G.view_toggle = function()
	local ft = vim.bo.filetype
	local cmd = view_commands[ft]
	if not cmd then
		vim.notify(
			"no rendered view for filetype " .. (ft ~= "" and ("'" .. ft .. "'") or "(none)"),
			vim.log.levels.WARN
		)
		return
	end
	vim.cmd(cmd)
end

vim.api.nvim_create_user_command("ViewToggle", _G.view_toggle, {
	desc = "Toggle the rendered view for this buffer's filetype",
})

-- md_open_link: built-in gx only sees a URL when the cursor is literally on it,
-- so on the text half of [label](url) it opens the word under the cursor. Walk
-- the markdown_inline tree instead to find the enclosing link's destination.
-- Falls through to the stock gx when there is no link, so nothing is lost.
local default_gx = vim.fn.maparg("gx", "n", false, true).callback

local function link_destination()
	local ok, node = pcall(vim.treesitter.get_node, { ignore_injections = false })
	if not ok or not node then
		return nil
	end
	while node do
		local kind = node:type()
		if kind == "uri_autolink" then
			return (vim.treesitter.get_node_text(node, 0):gsub("^<", ""):gsub(">$", ""))
		elseif kind == "link_destination" then
			return vim.treesitter.get_node_text(node, 0)
		elseif kind == "inline_link" or kind == "image" then
			for child in node:iter_children() do
				if child:type() == "link_destination" then
					return vim.treesitter.get_node_text(child, 0)
				end
			end
		end
		node = node:parent()
	end
	return nil
end

_G.md_open_link = function()
	local dest = link_destination()
	if not dest then
		if default_gx then
			return default_gx()
		end
		return vim.ui.open(vim.fn.expand("<cfile>"))
	end

	if dest:match("^%a[%w+.-]*://") or dest:match("^mailto:") then
		return vim.ui.open(dest)
	end

	-- Relative link to another file: open it in nvim rather than handing it to
	-- the system opener, which would launch it in some GUI app instead.
	local path = dest:gsub("#.*$", "")
	local base = vim.fn.expand("%:p:h")
	local target = vim.fs.normalize(path:match("^/") and path or (base .. "/" .. path))
	if vim.uv.fs_stat(target) then
		return vim.cmd.edit(vim.fn.fnameescape(target))
	end
	return vim.ui.open(dest)
end

vim.api.nvim_create_user_command("MdOpen", _G.md_open_link, {
	desc = "Open the markdown link under the cursor",
})

-- Scoped to markdown buffers: gx keeps its stock behaviour everywhere else.
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("MdOpenLink", { clear = true }),
	pattern = { "markdown", "mdx" },
	callback = function(args)
		vim.keymap.set("n", "gx", _G.md_open_link, {
			buffer = args.buf,
			desc = "Open markdown link under cursor",
		})
	end,
})

-- folder_finder: pick a child dir of cwd (or cwd itself) and chdir into it
_G.folder_finder = function()
	local cwd = vim.fn.getcwd()
	local dirs = vim.split(vim.fn.glob(cwd .. "/*/"), "\n", { trimempty = true })
	table.insert(dirs, 1, cwd)

	local items = {}
	for i, d in ipairs(dirs) do
		table.insert(items, { idx = i, text = d, file = d })
	end

	require("snacks").picker.pick({
		source = "folders",
		items = items,
		format = "text",
		title = "Pick Directory",
		confirm = function(picker, item)
			picker:close()
			if item then
				vim.api.nvim_set_current_dir(item.text)
				vim.notify("cwd → " .. item.text)
			end
		end,
	})
end
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
local function apply_transparency()
	vim.api.nvim_set_hl(0, "Normal", { bg = "none", ctermbg = "none" })
	vim.api.nvim_set_hl(0, "NonText", { bg = "none", ctermbg = "none" })
	vim.api.nvim_set_hl(0, "SignColumn", { bg = "none", ctermbg = "none" })
	vim.api.nvim_set_hl(0, "FoldColumn", { bg = "none", ctermbg = "none" })
	vim.api.nvim_set_hl(0, "LineNr", { bg = "none", ctermbg = "none" })
	vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "none", ctermbg = "none" })
	vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none", ctermbg = "none" })
	vim.api.nvim_set_hl(0, "StatusColumn", { bg = "none", ctermbg = "none" })
end

apply_transparency()

vim.api.nvim_create_autocmd({ "ColorScheme" }, {
	pattern = "*",
	callback = apply_transparency,
})
