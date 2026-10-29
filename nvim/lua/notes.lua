-- notes: the shared notes vault (~/Notes, configs/notes) from Neovim. One command, loaded on first
-- use (plugins/notes.lua); no keymaps.
--
--   :Notes                 find a note                 :Notes new <title>   Inbox/<title>.md
--   :Notes search [text]   grep the vault              :Notes today         Daily/YYYY-MM-DD.md
--   :Notes review          agent writes waiting in the outbox: diff preview, then apply,
--                          apply and always allow that file, or reject (the `notes` CLI)
--   :Notes grants          files agents may write without asking; pick one to revoke it
local M = {}

local vault = vim.fs.normalize(vim.env.NOTES_DIR or "~/Notes")

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "notes" })
end

-- Runs the `notes` CLI; returns stdout, or nil after reporting the error.
local function cli(args)
	local r = vim.system(vim.list_extend({ "notes" }, args), { text = true }):wait()
	if r.code ~= 0 then
		notify(vim.trim(r.stderr ~= "" and r.stderr or r.stdout), vim.log.levels.ERROR)
		return nil
	end
	return r.stdout
end

-- Opens a vault note, creating it with a heading when it doesn't exist yet.
local function open(rel, heading)
	local path = vault .. "/" .. rel
	if not vim.uv.fs_stat(path) then
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		vim.fn.writefile({ "# " .. heading, "" }, path)
	end
	vim.cmd.edit(vim.fn.fnameescape(path))
end

local function review()
	local out = cli({ "outbox", "--json" })
	if not out then
		return
	end
	local items = {}
	for i, q in ipairs(vim.json.decode(out)) do
		table.insert(items, {
			idx = i,
			q = q,
			text = string.format("%s  %s  %s", q.mode, q.path, q.source or ""),
			preview = { text = q.error and ("can't apply: " .. q.error) or q.diff, ft = "diff" },
		})
	end
	if #items == 0 then
		return notify("The outbox is empty.")
	end
	Snacks.picker.pick({
		title = "Notes outbox",
		items = items,
		format = "text",
		preview = "preview",
		confirm = function(picker, item)
			picker:close()
			if not item then
				return
			end
			local choices = item.q.error and { "Reject", "Skip" } or { "Apply", "Always for this file", "Reject", "Skip" }
			vim.ui.select(choices, { prompt = item.q.path }, function(choice)
				local done
				if choice == "Apply" then
					done = cli({ "apply", item.q.id })
				elseif choice == "Always for this file" then
					done = cli({ "apply", item.q.id, "--always" })
				elseif choice == "Reject" then
					done = cli({ "reject", item.q.id })
				end
				if done then
					notify(vim.trim(done))
				end
				if #items > 1 or not done then
					vim.schedule(review)
				end
			end)
		end,
	})
end

local function grants()
	local out = cli({ "grants", "--json" })
	if not out then
		return
	end
	local items = {}
	for i, g in ipairs(vim.json.decode(out)) do
		table.insert(items, { idx = i, g = g, text = string.format("%s  (since %s, %s)", g.path, g.since, g.source or "?") })
	end
	if #items == 0 then
		return notify("No files are approved for agents to write without asking.")
	end
	Snacks.picker.pick({
		title = "Notes grants (confirm to revoke)",
		items = items,
		format = "text",
		confirm = function(picker, item)
			picker:close()
			if not item then
				return
			end
			vim.ui.select({ "Revoke", "Keep" }, { prompt = item.g.path }, function(choice)
				if choice == "Revoke" then
					local done = cli({ "revoke", item.g.path })
					if done then
						notify(vim.trim(done))
					end
				end
			end)
		end,
	})
end

local subcommands = {
	search = function(arg)
		Snacks.picker.grep({ cwd = vault, search = arg ~= "" and arg or nil, hidden = false })
	end,
	new = function(arg)
		if arg == "" then
			return notify("usage: :Notes new <title>", vim.log.levels.WARN)
		end
		-- Obsidian names notes by title; only path separators and the characters phones refuse go.
		open("Inbox/" .. arg:gsub('[/\\:*?"<>|]', "-") .. ".md", arg)
	end,
	today = function()
		local day = os.date("%Y-%m-%d")
		open("Daily/" .. day .. ".md", day)
	end,
	review = review,
	grants = grants,
}

function M.setup()
	vim.api.nvim_create_user_command("Notes", function(opts)
		local sub, arg = opts.args:match("^(%S*)%s*(.-)%s*$")
		if sub == "" then
			return Snacks.picker.files({ cwd = vault, title = "Notes" })
		end
		local fn = subcommands[sub]
		if not fn then
			return notify("unknown :Notes " .. sub .. " (search, new, today, review, grants)", vim.log.levels.WARN)
		end
		fn(arg)
	end, {
		nargs = "*",
		desc = "Shared notes vault",
		complete = function(lead, line)
			if line:match("^%S+%s+%S+%s") then
				return {}
			end
			return vim.tbl_filter(function(s)
				return vim.startswith(s, lead)
			end, vim.tbl_keys(subcommands))
		end,
	})
end

return M
