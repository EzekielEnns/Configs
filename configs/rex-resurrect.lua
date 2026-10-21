-- Save and restore Rex sessions across server restarts (configs/rex.nix).
--
--   rex do resurrect.lua mode=daemon    restore missing sessions, then autosave
--   rex do resurrect.lua mode=save
--   rex do resurrect.lua mode=restore
--   rex do resurrect.lua mode=tmux [file=PATH] [session=NAME] [as=LABEL] [dry=true]
--                                       import a tmux-resurrect save
--
-- Saves session labels, tab labels, split layouts and each pane's directory.
-- Panes running Claude Code come back with `claude --resume <id>`, using the
-- id the SessionStart hook in configs/claude.nix records per pane.

local terminal = "com.superlogical.terminal"
local home = os.getenv("HOME")
local dir = home .. "/.local/state/rex-resurrect"
local snapshot = dir .. "/snapshot.json"

local function read(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

-- Write then rename, so a crash mid-save never leaves half a file
local function write(path, s)
  local tmp = path .. ".tmp"
  local f = assert(io.open(tmp, "w"))
  f:write(s)
  f:close()
  assert(os.rename(tmp, path))
end

local function claude_session(block_id)
  local s = read(dir .. "/claude/" .. (block_id:gsub("[^%w-]", "_")))
  return s and s:match("[%w-]+")
end

local function pane(session_id, block_id)
  local p = rex.block.call(terminal, "process", { session_id = session_id, block_id = block_id })
  local fg = p and p.foreground
  local node = { cwd = fg and fg.cwd or home }
  -- The binary is named after its version, but argv0 stays "claude"
  if fg and fg.argv0 == "claude" then
    local id = claude_session(block_id)
    node.cmd = id and ("claude --resume " .. id) or "claude --continue"
  end
  return node
end

local function walk(session_id, n)
  if n.split then
    return {
      dir = n.split.direction,
      ratio = n.split.ratio,
      before = walk(session_id, n.split.before),
      after = walk(session_id, n.split.after),
    }
  end
  return pane(session_id, n.block_id)
end

local function capture_session(s)
  -- view only works for attached sessions; attach returns the view too
  local a = rex.call("session.attach", { session_id = s.session_id })
  local v = a and a.view
  local windows = {}
  for _, w in ipairs(v and v.windows or {}) do
    for _, l in ipairs(w.layers or {}) do
      -- Floating layers are transient; only the tiled layout is kept
      if l.kind == "tiled" and l.layout then
        windows[#windows + 1] = {
          label = w.label,
          active = w.window_id == v.active_window_id or nil,
          layout = walk(s.session_id, l.layout),
        }
      end
    end
  end
  if #windows > 0 then return windows end
end

-- Only sessions with events since the last save are read again; the rest
-- come from cache. `all` forces a full pass, for changes no event reports.
local cache, dirty, all = {}, {}, true

local function capture()
  local out, live = {}, {}
  for _, s in ipairs(rex.call("session.list").sessions or {}) do
    local id = s.session_id
    if all or dirty[id] or cache[id] == nil then
      live[id] = capture_session(s) or false
    else
      live[id] = cache[id]
    end
    if live[id] then
      out[#out + 1] = { label = s.label, windows = live[id] }
    end
  end
  cache, dirty, all = live, {}, false
  return out
end

local last
local function save()
  local sessions = capture()
  -- A fresh server has nothing worth keeping; don't clobber the snapshot
  if #sessions == 0 then return end
  local text = rex.json.encode(sessions, { indent = true })
  if text == last then return end
  local old = read(snapshot)
  if old ~= text then
    if old then write(snapshot .. ".prev", old) end
    write(snapshot, text)
  end
  last = text
end

local function build(n)
  if n.dir then
    return { split = {
      direction = n.dir,
      ratio = n.ratio,
      before = build(n.before),
      after = build(n.after),
    } }
  end
  local options = { cwd = n.cwd }
  if n.cmd then options.initial_input = n.cmd .. "\n" end
  return { block = { flavor = "com.superlogical.terminal.shell", options = options } }
end

-- Skips sessions whose label already exists, so running it twice is harmless
local function restore(sessions)
  local have = {}
  for _, s in ipairs(rex.call("session.list").sessions or {}) do
    have[s.label] = true
  end
  local restored = {}
  for _, s in ipairs(sessions or {}) do
    if not have[s.label] then
      local windows, active = {}, nil
      for i, w in ipairs(s.windows) do
        windows[i] = { layout = build(w.layout) }
        if w.label and not w.label:match("^Window %x+$") then
          windows[i].window_label = w.label
        end
        if w.active then active = i end
      end
      local r, err = rex.call("session.create", { label = s.label, initial_windows = windows })
      if r then
        local w = active and r.initial_windows and r.initial_windows[active]
        if w then
          rex.call("session.focus_window", { session_id = r.session_id, window_id = w.window_id })
        end
        restored[#restored + 1] = s.label
      else
        rex.log("warn", "restore " .. s.label .. ": " .. tostring(err))
      end
    end
  end
  return restored
end

local function restore_snapshot()
  local text = read(snapshot)
  return text and restore(rex.json.decode(text)) or {}
end

-- tmux-resurrect save files: tab-separated `pane` and `window` lines. A
-- window's layout string (e.g. "8bd1,143x124,0,0[143x25,0,0,34,...]") nests
-- {} for side by side and [] for stacked; its leaves are the panes in order.
local function parse_layout(s)
  local i = s:find(",") + 1 -- skip the checksum
  local function node()
    local w, h, ni = s:match("^(%d+)x(%d+),%d+,%d+()", i)
    i = ni
    local open = s:sub(i, i)
    if open == "{" or open == "[" then
      local close = open == "{" and "}" or "]"
      local kids = {}
      i = i + 1
      repeat
        kids[#kids + 1] = node()
        local sep = s:sub(i, i)
        i = i + 1
      until sep == close
      return { dir = open == "{" and "horizontal" or "vertical", kids = kids,
        w = tonumber(w), h = tonumber(h) }
    end
    i = s:match("^,%d+()", i)
    return { w = tonumber(w), h = tonumber(h) }
  end
  return node()
end

-- tmux splits have any number of children; Rex's are binary, so chain them
local function to_tree(n, panes)
  if not n.kids then
    return table.remove(panes, 1) or { cwd = home }
  end
  local function size(k) return n.dir == "horizontal" and k.w or k.h end
  local function chain(from)
    if from == #n.kids then return to_tree(n.kids[from], panes) end
    local total = 0
    for j = from, #n.kids do total = total + size(n.kids[j]) end
    local before = to_tree(n.kids[from], panes)
    return { dir = n.dir, ratio = size(n.kids[from]) / total,
      before = before, after = chain(from + 1) }
  end
  return chain(1)
end

local function tmux_import(file)
  local text = read(file)
  if not text then error("no tmux-resurrect save at " .. file) end
  local order, sessions, panes = {}, {}, {}
  for line in text:gmatch("[^\n]+") do
    local f = {}
    for field in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = field end
    if f[1] == "window" then
      local name = f[2]
      if not sessions[name] then
        sessions[name] = { label = name, windows = {} }
        order[#order + 1] = name
      end
      sessions[name].windows[#sessions[name].windows + 1] = {
        index = tonumber(f[3]), label = f[4]:sub(2), active = f[5] == "1" or nil,
        layout_string = f[7],
      }
    elseif f[1] == "pane" then
      -- The title can be missing, so find fields relative to the directory
      local d
      for j = 6, #f do
        if f[j]:sub(1, 1) == ":" and f[j]:sub(2, 2) == "/" then d = j break end
      end
      if d then
        local key = f[2] .. "\t" .. f[3]
        local cwd, prog, full = f[d]:sub(2), f[d + 2], f[#f]:sub(2)
        local node = { cwd = cwd, index = tonumber(f[6]) }
        if full:match("^claude") then
          -- tmux only recorded an id when the pane was started with one;
          -- otherwise open the picker (--continue could double up a session)
          node.cmd = full:match("%-%-resume %S+") and full or "claude --resume"
        elseif prog == "nvim" or prog == "vim" then
          node.cmd = prog
        end
        panes[key] = panes[key] or {}
        panes[key][#panes[key] + 1] = node
      end
    end
  end
  local out = {}
  for _, name in ipairs(order) do
    local s = sessions[name]
    if rex.args.session and name ~= rex.args.session then goto continue end
    if rex.args.as then s.label = rex.args.as end
    table.sort(s.windows, function(a, b) return a.index < b.index end)
    for _, w in ipairs(s.windows) do
      local ps = panes[name .. "\t" .. w.index] or {}
      table.sort(ps, function(a, b) return a.index < b.index end)
      w.layout = to_tree(parse_layout(w.layout_string), ps)
      w.index, w.layout_string = nil, nil
    end
    out[#out + 1] = s
    ::continue::
  end
  return out
end

rex.exec({ "mkdir", "-p", dir .. "/claude" })
local mode = rex.args.mode or "save"

if mode == "restore" then
  return restore_snapshot()
elseif mode == "save" then
  save()
  return snapshot
elseif mode == "tmux" then
  local file = rex.args.file or (home .. "/.tmux/resurrect/last")
  if rex.args.dry then return tmux_import(file) end
  return restore(tmux_import(file))
end

-- daemon: restore first so a fresh server's near-empty state isn't saved
restore_snapshot()
save()

local timer
local function soon(ctx, ev)
  local id = (ev and ev.session_id) or (ctx and ctx.session_id)
  if id then dirty[id] = true else all = true end
  if timer then timer:cancel() end
  timer = rex.after(2, save)
end
for _, event in ipairs({
  "session_created", "session_destroyed", "session_view_changed",
  "session_label_changed", "window_label_changed",
  "terminal.process_changed", "terminal.pwd_changed",
}) do
  rex.on(event, soon)
end
-- `cd` in zsh raises no event, so re-read everything once a minute
-- (the file is only written when something changed)
rex.every(60, function()
  all = true
  save()
end)
