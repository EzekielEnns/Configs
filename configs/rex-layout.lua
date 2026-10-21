-- Turn every split in the current tab 90 degrees, so side by side becomes
-- stacked and back. Loaded from init.lua (configs/rex.nix).

local function first_block(n)
  while n.split do n = n.split.before end
  return n.block_id
end

local function tiled_layout(view)
  for _, w in ipairs(view.windows or {}) do
    if w.window_id == view.active_window_id then
      for _, l in ipairs(w.layers or {}) do
        if l.kind == "tiled" then return l.layout end
      end
    end
  end
end

rex.action{
  name = "flip_layout",
  title = "Flip Layout",
  description = "Turn every split in this tab: side by side becomes stacked, and back",
  keywords = "rotate orientation vertical horizontal stack monitor",
  run = function(ctx)
    local sid = ctx.session_id
    local view, err = rex.call("session.view", { session_id = sid })
    if not view then error(err, 0) end
    local layout = tiled_layout(view)
    if not layout or not layout.split then return end

    -- Rebuild from the top. When a split is reached, its first `before`
    -- block already fills the split's space, so moving the first `after`
    -- block beside it recreates the split, turned. Blocks left in the old
    -- layout fall away as they are moved.
    local function place(n)
      if not n.split then return end
      local s = n.split
      local _, e = rex.call("session.move_block", {
        session_id = sid,
        block_id = first_block(s.after),
        anchor_block_id = first_block(s.before),
        direction = s.direction == "horizontal" and "vertical" or "horizontal",
        ratio = s.ratio,
      })
      if e then error(e, 0) end
      place(s.before)
      place(s.after)
    end
    place(layout)

    if ctx.block_id then
      rex.call("session.focus_block", { session_id = sid, block_id = ctx.block_id })
    end
  end,
}
