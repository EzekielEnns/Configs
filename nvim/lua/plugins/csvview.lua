-- Renders CSV/TSV as an aligned table using inline extmarks. The padding is
-- virtual text only, so nothing is written back to the file.
return {
	"hat0uma/csvview.nvim",
	ft = { "csv", "tsv" },
	cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
	---@module "csvview"
	---@type CsvView.Options
	opts = {
		view = {
			-- Draw a │ between columns instead of only recolouring the commas.
			display_mode = "border",
			-- Pin the header row to the top of the window while scrolling.
			sticky_header = { enabled = true },
			-- For very wide files, sticky_columns = { enabled = true, count = 1 }
			-- freezes the leftmost column like a spreadsheet.
		},
		parser = {
			comments = { "#", "//" },
		},
		-- Deliberately empty. csvview binds nothing by default, and the motions
		-- its README suggests (<Tab>, <S-Tab>, <Enter>, <S-Enter>) would shadow
		-- jumplist-forward and plain <CR> for as long as a CSV buffer is open.
		keymaps = {},
	},
	config = function(_, opts)
		local csvview = require("csvview")
		csvview.setup(opts)

		local function enable(buf)
			-- spell is on globally; it underlines every cell of a CSV and none
			-- of this is prose. Drop this line to keep spell checking.
			vim.opt_local.spell = false
			if not csvview.is_enabled(buf) then
				csvview.enable(buf)
			end
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("CsvViewAuto", { clear = true }),
			pattern = { "csv", "tsv" },
			callback = function(args)
				enable(args.buf)
			end,
		})

		-- lazy.nvim loads this plugin *because* a csv buffer opened, so the
		-- FileType event for that buffer has already gone by.
		if vim.tbl_contains({ "csv", "tsv" }, vim.bo.filetype) then
			enable(0)
		end
	end,
}
