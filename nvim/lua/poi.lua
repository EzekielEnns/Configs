-- poi: points of interest from the `poi` CLI (configs/poi): Jev ranks the code against a question,
-- optionally Flint writes a guided tour or the hits are put in call order (flow). Results land in
-- the quickfix list (]q / [q or :cn walk them; the text is each stop's explanation, so Trouble's
-- quickfix view reads like the tour) and in a snacks picker with file preview.
--
--   :Poi <question>        rank the code under the cwd        :Poi! [ref] [focus]   rank a diff
--   :PoiFlow <question>    same, in call order                 :PoiFlow! [ref] [focus]
--   :PoiLoad <file.json>   load a saved `poi --json` result (what `poi --open` uses)
--   :PoiLast               the last result's picker again
-- Flags pass through: `:Poi --tour where is X`, `:Poi --follow ...`, `:Poi --files 30 ...`.
local M = {}

local last -- the last result (decoded JSON)

local function notify(msg, level, opts)
	vim.notify(msg, level or vim.log.levels.INFO, vim.tbl_extend("force", { title = "poi", id = "poi" }, opts or {}))
end

-- What to walk, as in poi's stops_of: flow steps, else tour stops, else hits.
local function stops(res)
	local out = {}
	if res.flow then
		for _, h in ipairs(res.hits) do
			if not h.url then
				table.insert(out, { file = h.file, line = h.line, ["end"] = h["end"], text = h.step .. ". " .. h.text })
			end
		end
	elseif res.tour and res.tour.stops and #res.tour.stops > 0 then
		for _, s in ipairs(res.tour.stops) do
			table.insert(out, { file = s.file, line = s.line, ["end"] = s["end"], text = s.step .. ". " .. s.text })
		end
	else
		for _, h in ipairs(res.hits) do
			if not h.url then
				local sym = (h.symbol and h.symbol ~= "") and (h.symbol .. " — ") or ""
				table.insert(out, {
					file = h.file,
					line = h.line,
					["end"] = h["end"],
					text = string.format("[%.2f] %s%s", h.score, sym, h.preview),
				})
			end
		end
	end
	return out
end

local function abs(res, file)
	if file:sub(1, 1) == "/" then
		return file
	end
	return res.root .. "/" .. file
end

local function to_qf(res)
	local items = {}
	for _, s in ipairs(stops(res)) do
		table.insert(items, { filename = abs(res, s.file), lnum = s.line, end_lnum = s["end"], col = 1, text = s.text })
	end
	vim.fn.setqflist({}, " ", { title = "poi: " .. res.question, items = items })
	return items
end

local function picker(res)
	local ok, Snacks = pcall(require, "snacks")
	if not ok or not Snacks.picker then
		vim.cmd("copen")
		return
	end
	local items = {}
	for i, s in ipairs(stops(res)) do
		table.insert(items, {
			idx = i,
			text = s.file .. " " .. s.text,
			file = abs(res, s.file),
			pos = { s.line, 0 },
			end_pos = s["end"] and { s["end"], 0 } or nil,
			rel = s.file .. ":" .. s.line,
			label = s.text,
		})
	end
	Snacks.picker.pick({
		source = "poi",
		title = "poi: " .. res.question,
		items = items,
		format = function(item)
			return { { item.rel, "SnacksPickerFile" }, { "  " }, { item.label, "SnacksPickerComment" } }
		end,
		preview = "file",
		confirm = function(p, item)
			p:close()
			if item then
				vim.fn.setqflist({}, "a", { idx = item.idx })
				vim.cmd("cc " .. item.idx)
			end
		end,
	})
end

local function summary(res)
	local c = res.cost or {}
	local s = string.format("%d stops · %d Jev requests · $%.4f · %ds", #stops(res), c.jev_requests or 0, c.usd or 0,
		math.floor(c.seconds or 0))
	if res.tour and res.tour.answer and res.tour.answer ~= "" then
		s = s .. "\n" .. res.tour.answer
	end
	return s
end

--- Show a result: quickfix list, then the picker (or, with opts.first, jump to the first stop).
function M.show(res, opts)
	opts = opts or {}
	last = res
	local items = to_qf(res)
	if #items == 0 then
		notify("no places found", vim.log.levels.WARN)
		return
	end
	notify(summary(res), nil, { timeout = 6000 })
	if opts.first then
		vim.cmd("cfirst")
		local ok = pcall(vim.cmd, "Trouble qflist open focus=false win.position=bottom")
		if not ok then
			vim.cmd("copen | wincmd p")
		end
	else
		picker(res)
	end
end

function M.load(path)
	local f = io.open(vim.fn.expand(path), "r")
	if not f then
		notify("can't read " .. path, vim.log.levels.ERROR)
		return
	end
	local ok, res = pcall(vim.json.decode, f:read("*a"))
	f:close()
	if not ok or type(res) ~= "table" or not res.hits then
		notify("not a poi result: " .. path, vim.log.levels.ERROR)
		return
	end
	M.show(res, { first = true })
end

local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

--- Run `poi --json` asynchronously in the cwd. `words`: the command's arguments as typed; tokens starting
--- with -- are flags, the rest the question (diff mode: an optional ref, then the focus).
function M.run(words, opts)
	opts = opts or {}
	local flags, rest = { "--json" }, {}
	local i = 1
	while i <= #words do
		local w = words[i]
		if w:match("^%-%-") then
			table.insert(flags, w)
			if (w == "--files" or w == "--tour-model" or w == "-n") and words[i + 1] then
				table.insert(flags, words[i + 1])
				i = i + 1
			end
		else
			table.insert(rest, w)
		end
		i = i + 1
	end
	if opts.flow then
		table.insert(flags, "--flow")
	end
	if opts.tour and not vim.tbl_contains(flags, "--tour") then
		table.insert(flags, "--tour")
	end
	local cmd = { "poi" }
	vim.list_extend(cmd, flags)
	if opts.diff then
		table.insert(cmd, "--diff")
		vim.list_extend(cmd, rest)
	else
		if #rest == 0 then
			notify("give a question", vim.log.levels.WARN)
			return
		end
		table.insert(cmd, table.concat(rest, " "))
	end
	if vim.fn.executable("poi") == 0 then
		notify("`poi` isn't on PATH (configs/agents.nix)", vim.log.levels.ERROR)
		return
	end
	local frame, t0 = 1, vim.uv.now()
	local timer = vim.uv.new_timer()
	timer:start(0, 120, vim.schedule_wrap(function()
		frame = frame % #spinner + 1
		notify(spinner[frame] .. " " .. table.concat(rest, " ") .. string.format("  (%ds)", (vim.uv.now() - t0) / 1000),
			nil, { timeout = false })
	end))
	vim.system(cmd, { cwd = vim.fn.getcwd(), text = true }, function(out)
		vim.schedule(function()
			timer:stop()
			timer:close()
			if out.code ~= 0 then
				local err = (out.stderr or ""):gsub("%s+$", "")
				notify(err:match("poi: [^\n]*$") or err, vim.log.levels.ERROR, { timeout = 8000 })
				return
			end
			local ok, res = pcall(vim.json.decode, out.stdout)
			if not ok then
				notify("couldn't read poi's output", vim.log.levels.ERROR)
				return
			end
			M.show(res)
		end)
	end)
end

function M.setup()
	local function cmd(name, run_opts)
		vim.api.nvim_create_user_command(name, function(a)
			M.run(a.fargs, vim.tbl_extend("force", run_opts, { diff = a.bang }))
		end, { nargs = "*", bang = true, desc = "poi: points of interest (! = the diff)" })
	end
	cmd("Poi", {})
	cmd("PoiFlow", { flow = true })
	vim.api.nvim_create_user_command("PoiLoad", function(a)
		M.load(a.args)
	end, { nargs = 1, complete = "file", desc = "poi: load a saved --json result" })
	vim.api.nvim_create_user_command("PoiLast", function()
		if last then
			picker(last)
		else
			notify("nothing yet", vim.log.levels.WARN)
		end
	end, { desc = "poi: the last result again" })

	local function ask(prompt, run_opts)
		return function()
			vim.ui.input({ prompt = prompt }, function(q)
				if q and q ~= "" then
					M.run(vim.split(q, "%s+", { trimempty = true }), run_opts)
				elseif run_opts.diff then
					M.run({}, run_opts)
				end
			end)
		end
	end
	local map = function(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { desc = desc })
	end
	map("<leader>ii", ask("poi: ", {}), "poi: points of interest")
	map("<leader>it", ask("poi tour: ", { tour = true }), "poi: guided tour (Flint)")
	map("<leader>if", ask("poi flow: ", { flow = true }), "poi: in call order")
	map("<leader>id", ask("poi diff focus (empty = risky changes): ", { diff = true, flow = true }), "poi: review the diff")
	map("<leader>il", "<cmd>PoiLast<cr>", "poi: last result")
end

return M
