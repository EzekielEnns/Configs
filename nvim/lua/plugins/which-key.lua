return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	dependencies = {
		"simeji/winresizer",
		"f-person/git-blame.nvim",
		"sindrets/diffview.nvim",
	},
	config = function()
		vim.g.mapleader = " "
		local wk = require("which-key")

		wk.add({
			--nav
			{ "<leader>f", function() require("snacks").picker.files() end, desc = "find files" },
			{ "<leader><C-w>", "<cmd>WinResizerStartResize<cr>", desc = "Resize window" },
			{ "<leader>w", "<cmd>set list!<CR>", desc = "toggle white space" },
			{ "<leader>v", "<cmd>ViewToggle<cr>", desc = "toggle rendered view (csv/markdown)" },
			{ "<leader>o", "<cmd>MdOpen<cr>", desc = "open link/file under cursor" },
			{ "<leader>b", function() require("snacks").picker.buffers() end, desc = "find buffers" },
			{ "<leader>/", function() require("snacks").picker.grep() end, desc = "find text" },
			{ "<leader>j", function() require("snacks").picker.jumps() end, desc = "jumplist" },
			{ "<leader>m", function() require("snacks").picker.marks() end, desc = "marks" },
			{ "<leader>d", function() require("snacks").picker.diagnostics() end, desc = "diagnostics" },
			--lsp
			{ "<leader>ls", function() require("snacks").picker.lsp_symbols() end, desc = "document symbols" },
			{ "<leader>lw", function() require("snacks").picker.lsp_workspace_symbols() end, desc = "workspace symbols" },
			{ "<leader>lr", function() require("snacks").picker.lsp_references() end, desc = "references" },
			{ "<leader>li", function() require("snacks").picker.lsp_implementations() end, desc = "implementation" },

			--explore
			{ "<leader>cd", "<cmd>lua folder_finder()<cr>", desc = "find Directory" },
			{ "<leader>eo", "<cmd>Oil<cr>", desc = "Oil (q/Esc to close, - to go up)" },

			--git
			{
				"<leader>gb",
				function()
					-- git status, but only files with unstaged changes or untracked.
					-- item.status is the porcelain XY code: X = index, Y = worktree.
					require("snacks").picker.git_status({
						title = "Unstaged",
						filter = {
							filter = function(item)
								local s = item.status or ""
								return s == "??" or s:sub(2, 2) ~= " "
							end,
						},
					})
				end,
				desc = "unstaged files",
			},
			{ "<leader>gl", "<cmd>GitBlameToggle<CR>", desc = "git blame" },
			{ "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "git diff open" },
			{ "<leader>gc", "<cmd>DiffviewClose<CR>", desc = "git diff close" },
			{ "<leader>gg", function() require("snacks").lazygit() end, desc = "lazygit" },
			{ "<leader>gB", function() require("snacks").gitbrowse() end, desc = "git browse (open in github)" },
			{ "<leader>gr", "<cmd>Octo pr list<cr>", desc = "review PRs (octo)" },
			{ "<leader>gh", group = "hunk" },
			{ "<leader>ghf", function() require("snacks").picker.git_diff() end, desc = "find hunk (diff picker)" },

			--terminal
			{ "<leader>tt", function() require("snacks").terminal() end, desc = "toggle terminal" },

			--go (go.nvim, only defined in go buffers)
			{ "<leader>G", group = "go" },
			{ "<leader>Gt", "<cmd>GoTestPkg<cr>", desc = "test package" },
			{ "<leader>GT", "<cmd>GoTestFunc<cr>", desc = "test function under cursor" },
			{ "<leader>Gf", "<cmd>GoTestFile<cr>", desc = "test file" },
			{ "<leader>Gc", "<cmd>GoCoverage<cr>", desc = "coverage (toggle)" },
			{ "<leader>Ga", "<cmd>GoAlt!<cr>", desc = "alternate file (foo.go <-> foo_test.go)" },
			{ "<leader>GA", "<cmd>GoAddTest<cr>", desc = "generate test for func (gotests)" },
			{ "<leader>Gr", "<cmd>GoRun<cr>", desc = "go run" },
			{ "<leader>Gb", "<cmd>GoBuild<cr>", desc = "go build" },
			{ "<leader>Gl", "<cmd>GoLint<cr>", desc = "golangci-lint (package)" },
			{ "<leader>Gv", "<cmd>GoVet<cr>", desc = "go vet" },
			{ "<leader>Gm", "<cmd>GoModTidy<cr>", desc = "go mod tidy" },
			{ "<leader>Gg", "<cmd>GoGenerate<cr>", desc = "go generate" },
			{ "<leader>Gs", "<cmd>GoFillStruct<cr>", desc = "fill struct" },
			{ "<leader>Gi", "<cmd>GoImpl<cr>", desc = "implement interface" },
			{ "<leader>Ge", "<cmd>GoIfErr<cr>", desc = "insert if err != nil" },
			{ "<leader>Gj", "<cmd>GoAddTag json<cr>", desc = "add json tags" },
			{ "<leader>Gy", "<cmd>GoAddTag yaml<cr>", desc = "add yaml tags" },
			{ "<leader>Gx", "<cmd>GoRmTag<cr>", desc = "remove tags" },
			{ "<leader>Gd", "<cmd>GoDoc<cr>", desc = "go doc" },
			{ "<leader>GD", "<cmd>GoDebug<cr>", desc = "debug (delve)" },
			{ "<leader>GB", "<cmd>GoBreakToggle<cr>", desc = "toggle breakpoint" },
			{ "<leader>GS", "<cmd>GoDbgStop<cr>", desc = "stop debugger" },

			--jupyter (pyrepl.nvim)
			{ "<leader>k", group = "kernel/notebook" },
			{ "<leader>kt", "<cmd>PyreplToggle<cr>", desc = "toggle repl" },
			{ "<leader>ko", "<cmd>PyreplOpen<cr>", desc = "open repl" },
			{ "<leader>kO", "<cmd>PyreplOpen!<cr>", desc = "open repl (pick kernel)" },
			{ "<leader>kh", "<cmd>PyreplHide<cr>", desc = "hide repl" },
			{ "<leader>kq", "<cmd>PyreplClose<cr>", desc = "close repl" },
			{ "<leader>kb", "<cmd>PyreplSendBuffer<cr>", desc = "send buffer" },
			{ "<leader>kl", "<cmd>PyreplSendCell<cr>", desc = "send cell" },
			{ "<leader>kv", "<cmd>PyreplSendVisual<cr>", desc = "send selection", mode = "v" },
			{ "<leader>kn", "<cmd>PyreplStepCellForward<cr>", desc = "next cell" },
			{ "<leader>kp", "<cmd>PyreplStepCellBackward<cr>", desc = "prev cell" },
			{ "<leader>ki", "<cmd>PyreplOpenImageHistory<cr>", desc = "plot history" },
			{ "<leader>kc", "<cmd>PyreplConvert<cr>", desc = "convert .ipynb to script" },
			{ "<leader>ke", "<cmd>PyreplExport<cr>", desc = "export script to .ipynb" },
			{ "<leader>kI", ":PyreplInstall ", desc = "install repl packages (uv|pip)" },
			{ "<M-r>", "<cmd>PyreplToggleFocus<cr>", desc = "toggle repl focus", mode = { "n", "t" } },

			--trouble
			{ "<leader>x", group = "trouble" },
			{ "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "diagnostics" },
			{ "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "buffer diagnostics" },
			{ "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "symbols" },
			{ "<leader>xl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "lsp refs" },
			{ "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "location list" },
			{ "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", desc = "quickfix list" },

			--refactor
			{ "<leader>r", group = "refactor" },
			{ "<leader>re", desc = "extract function", mode = "v" },
			{ "<leader>rf", desc = "extract function to file", mode = "v" },
			{ "<leader>rv", desc = "extract variable", mode = "v" },
			{ "<leader>ri", desc = "inline variable", mode = { "n", "v" } },
			{ "<leader>rb", desc = "extract block" },
			{ "<leader>rbf", desc = "extract block to file" },
			{ "<leader>rr", desc = "select refactor", mode = { "n", "v" } },

			{ "<leader>h", "<cmd>lua vim.lsp.buf.signature_help()<cr>", desc = "lsp sig help" },
			{ "<leader>lh", "<cmd>lua vim.lsp.buf.hover()<cr>", desc = "hover" },
			{ "<leader>lH", "<cmd>lua vim.diagnostic.open_float()<cr>", desc = "diagnostic" },
			{ "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>", desc = "code action" },
			{ "<leader>lR", "<cmd>lua vim.lsp.buf.rename()<cr>", desc = "rename" },
			{ "<leader>lt", function() require("snacks").picker.lsp_type_definitions() end, desc = "type definition" },
			{ "<leader>]", "<cmd>lua vim.diagnostic.goto_prev()<cr>", desc = "prev diagnostic" },
			{ "<leader>[", "<cmd>lua vim.diagnostic.goto_next()<cr>", desc = "next diagnostic" },

			--helpful
			{ "<leader>tr", "<cmd>setlocal relativenumber!<CR>", desc = "toggle relative lines", mode = { "v", "n" } },
			{ "<leader>nh", "<cmd>nohlsearch<CR>", desc = "toggle highlight", mode = { "v", "n" } },
			{ "<leader>p", '"+p', desc = "paste from clip", mode = { "v", "n" } },
			{ "<leader>P", '"+P', desc = "paste from clip", mode = { "v", "n" } },
			{ "<leader>y", '"+y', desc = "yank to clip", mode = { "v", "n" } },
			{ "<leader>yy", '"+yy', desc = "yank line to clip", mode = { "v", "n" } },
			{ "<leader>Y", '"+yg_', desc = "yank line", mode = { "v", "n" } },
			{
				"<leader>cf",
				function()
					-- Base name (filename only)
					local base = vim.fn.expand("%:t")
					vim.fn.setreg("+", base)
					vim.notify("Copied file name:\n" .. base)
				end,
				desc = "copy base file name",
			},

			{
				"<leader>cp",
				function()
					-- Base path (directory), relative to cwd (same logic as your snippet)
					local root = vim.fn.getcwd()
					local dir = vim.fn.expand("%:p:h")
					local rel = vim.fn.fnamemodify(dir, ":~:.")
					if dir:find(root, 1, true) == 1 then
						rel = dir:sub(#root + 2)
					end
					vim.fn.setreg("+", rel)
					vim.notify("Copied directory path:\n" .. rel)
				end,
				desc = "copy base path (directory) relative to root",
			},

			{
				"<leader>cl",
				function()
					-- Line number only
					local line = tostring(vim.fn.line("."))
					vim.fn.setreg("+", line)
					vim.notify("Copied line number:\n" .. line)
				end,
				desc = "copy line number",
			},
			{
				"<leader>cr",
				function()
					local root = vim.fn.getcwd()
					local file = vim.fn.expand("%:p")
					local rel_path = vim.fn.fnamemodify(file, ":~:.")
					if file:find(root, 1, true) == 1 then
						rel_path = file:sub(#root + 2)
					end
					local pos = rel_path .. ":" .. vim.fn.line(".") .. ":" .. vim.fn.col(".")
					vim.fn.setreg("+", pos)
					vim.notify("Copied cursor location:\n" .. pos)
				end,
				desc = "copy cursor location relative to root",
			},
			{
				"<leader>ch",
				function()
					local line = vim.api.nvim_get_current_line()
					local row = vim.api.nvim_win_get_cursor(0)[1]
					local col = vim.api.nvim_win_get_cursor(0)[2]

					if #line <= 100 then
						return
					end

					local indent = line:match("^%s*")
					local content = line:sub(#indent + 1)

					local parts = {}
					while #content > 0 do
						local max_len = 100 - #indent
						if #content <= max_len then
							table.insert(parts, indent .. content)
							break
						end

						-- Find the last space before the 100-character limit
						local cut_pos = nil
						for i = max_len, 1, -1 do
							if content:sub(i, i):match("%s") then
								cut_pos = i
								break
							end
						end

						-- If no space found, don't split this line
						if not cut_pos then
							table.insert(parts, indent .. content)
							break
						end

						table.insert(parts, indent .. content:sub(1, cut_pos - 1))
						content = content:sub(cut_pos + 1):gsub("^%s+", "")
					end

					vim.api.nvim_buf_set_lines(0, row - 1, row, false, parts)
					vim.api.nvim_win_set_cursor(0, { row, math.min(col, #parts[1]) })
				end,
				desc = "chop line at 100 chars",
			},
		})
	end,
}
