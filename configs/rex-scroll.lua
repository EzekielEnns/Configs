-- One scroll mode for every pane (configs/rex.nix). A shell jumps between
-- prompts; a full-screen program such as Claude Code or nvim, which has no
-- prompts and no scrollback, gets Page Up / Page Down instead.

local terminal = "com.superlogical.terminal"

-- Alternate screen modes: 1049 and 1047, plus the legacy 47
local alt_screen = { [47] = true, [1047] = true, [1049] = true }

local function full_screen(block_id)
  local r = rex.block.call(terminal, "modes", { block_id = block_id })
  for _, m in ipairs(r and r.modes or {}) do
    if alt_screen[m.number] and m.set then return true end
  end
  return false
end

rex.action{
  name = "scroll_step",
  title = "Scroll Step",
  description = "Previous or next prompt in a shell, Page Up or Page Down in a full-screen program",
  args = { direction = "string" },
  run = function(ctx, args)
    local up = args.direction == "up"
    if ctx.block_id and full_screen(ctx.block_id) then
      rex.block.call(terminal, "write", {
        block_id = ctx.block_id,
        data = up and "\27[5~" or "\27[6~",
      })
    else
      rex.client.queue(up and "client.prompt.previous" or "client.prompt.next")
    end
  end,
}
