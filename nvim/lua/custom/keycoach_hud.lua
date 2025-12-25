-- ~/.config/nvim/lua/custom/keycoach_hud.lua
-- KeyCoach HUD: bottom split "sidebar" that updates based on key sequences.

local M = {}

-- ---------- Trie helpers ----------
local function node(label, entries, children)
  -- entries: ordered list of {key, desc}
  return { label = label or "", entries = entries or {}, children = children or {} }
end

local function entries(...)
  return { ... } -- ordered; rendered in this order
end

-- ---------- Rendering (multi-column grid) ----------
local function render_grid(lines, win_width, list, cols)
  cols = cols or 4
  if win_width < 90 then cols = 3 end
  if win_width < 70 then cols = 2 end
  if win_width < 50 then cols = 1 end

  local arrow = " -> "
  local cells = {}

  local keyw = 0
  for _, it in ipairs(list) do
    keyw = math.max(keyw, vim.fn.strdisplaywidth(it[1]))
  end
  keyw = math.min(math.max(keyw, 1), 10)

  for _, it in ipairs(list) do
    local k = it[1]
    local d = it[2]
    local kpad = k .. string.rep(" ", math.max(0, keyw - vim.fn.strdisplaywidth(k)))
    cells[#cells + 1] = kpad .. arrow .. d
  end

  local col_sep = "   "
  local sepw = vim.fn.strdisplaywidth(col_sep)

  -- Determine column width budget
  local available = win_width
  local colw = math.floor((available - (cols - 1) * sepw) / cols)
  if colw < 18 then cols = math.max(1, cols - 1) end
  colw = math.floor((available - (cols - 1) * sepw) / cols)

  local function clip(s, w)
    if vim.fn.strdisplaywidth(s) <= w then return s end
    -- crude clip with ellipsis
    return vim.fn.strcharpart(s, 0, math.max(0, w - 1)) .. "…"
  end

    local rows = math.ceil(#cells / cols)
    for r = 1, rows do
    	local parts = {}
    	for c = 1, cols do
      -- Column-major fill: index advances down the column first
      local idx = (c - 1) * rows + r
      local cell = cells[idx]
      if not cell then
        -- keep alignment: empty cell
        local pad = string.rep(" ", math.max(0, colw))
        parts[#parts + 1] = pad
      else
        local clipped = clip(cell, colw)
        local pad = colw - vim.fn.strdisplaywidth(clipped)
        parts[#parts + 1] = clipped .. string.rep(" ", math.max(0, pad))
      end
    end
    lines[#lines + 1] = table.concat(parts, col_sep)
  end
end
-- ---------- Default tree (maximal practical root) ----------
local function build_tree()
  -- Motions/textobjs after operators
  local OP = entries(
    { "w", "Next word" }, { "b", "Prev word" }, { "e", "Next end of word" },
    { "W", "Next WORD" }, { "B", "Prev WORD" }, { "E", "Next end of WORD" },
    { "0", "Start of line" }, { "^", "Start of line (non-ws)" }, { "$", "End of line" },
    { "f{c}", "Find char" }, { "F{c}", "Find char back" },
    { "t{c}", "Till char" }, { "T{c}", "Till char back" },
    { ";", "Repeat ftFT" }, { ",", "Repeat ftFT back" },
    { "%", "Match pair (){}[]" },
    { "{", "Prev paragraph" }, { "}", "Next paragraph" },
    { "(", "Prev sentence" }, { ")", "Next sentence" },
    { "gg", "Top of file" }, { "G", "Bottom of file" },
    { "i{obj}", "Inside textobj (iw, i\", i(…)" },
    { "a{obj}", "Around textobj (aw, a\", a(…)" }
  )

  -- Root: dense normal-mode “cheat sheet”
  local root = node("NORMAL — starters (maximal practical)", entries(
    -- Movement
    { "h", "Left" }, { "j", "Down" }, { "k", "Up" }, { "l", "Right" },
    { "w", "Next word" }, { "b", "Prev word" }, { "e", "Next end of word" },
    { "W", "Next WORD" }, { "B", "Prev WORD" }, { "E", "Next end of WORD" },
    { "0", "Start of line" }, { "^", "Start (non-ws)" }, { "$", "End of line" },
    { "gg", "Top of file" }, { "G", "Last line" },
    { "H", "Top of screen" }, { "M", "Middle of screen" }, { "L", "Bottom of screen" },
    { "<C-d>", "Half page down" }, { "<C-u>", "Half page up" },
    { "<C-f>", "Page down" }, { "<C-b>", "Page up" },

    -- Find / search
    { "f", "Find char" }, { "F", "Find back" }, { "t", "Till char" }, { "T", "Till back" },
    { ";", "Repeat ftFT" }, { ",", "Repeat ftFT back" },
    { "/", "Search forward" }, { "?", "Search backward" },
    { "n", "Next match" }, { "N", "Prev match" },
    { "*", "Search word fwd" }, { "#", "Search word back" },

    -- Insert / Visual
    { "i", "Insert" }, { "a", "Append" }, { "I", "Insert line start" }, { "A", "Append line end" },
    { "o", "Open below" }, { "O", "Open above" },
    { "v", "Visual" }, { "V", "Visual line" }, { "<C-v>", "Visual block" },

    -- Operators / edits
    { "d", "Delete (operator)" }, { "c", "Change (operator)" }, { "y", "Yank (operator)" },
    { "x", "Del char" }, { "X", "Del char back" },
    { "p", "Paste" }, { "P", "Paste before" },
    { "s", "Substitute char" }, { "S", "Substitute line" },
    { "r", "Replace char" }, { "R", "Replace mode" },
    { "J", "Join lines" }, { "~", "Toggle case" },
    { ".", "Repeat last change" }, { "u", "Undo" }, { "<C-r>", "Redo" },

    -- Command-line + misc
    { ":", "Command-line" },
    { "\"", "Registers" },
    { "q", "Record macro" }, { "@", "Play macro" },
    { "m", "Set mark" }, { "'", "Jump mark (line)" }, { "`", "Jump mark (exact)" },

    -- Prefix families (these expand)
    { "g", "+6 keymaps" },
    { "z", "+6 keymaps" },
    { "<C-w>", "+Window keymaps" },
    { "[", "+1 keymap" },
    { "]", "+1 keymap" }
  ), {})

  -- Operators
  local del = node("d — DELETE: pick motion/textobj", OP, {})
  local chg = node("c — CHANGE: pick motion/textobj", OP, {})
  local ynk = node("y — YANK: pick motion/textobj", OP, {})

  del.children["d"] = node("dd — delete line", entries({ "✓", "done" }), {})
  chg.children["c"] = node("cc — change line", entries({ "✓", "done" }), {})
  ynk.children["y"] = node("yy — yank line", entries({ "✓", "done" }), {})

  -- g prefix
  local g = node("g — goto/misc", entries(
    { "g", "gg: Top of file" },
    { "d", "gd: Definition" },
    { "D", "gD: Declaration" },
    { "i", "gi: Last insert" },
    { "f", "gf: File under cursor" },
    { "F", "gF: File in new tab" },
    { "t", "gt: Next tab" },
    { "T", "gT: Prev tab" }
  ), {})
  g.children["g"] = node("gg — top of file", entries({ "✓", "done" }), {})

  -- z prefix
  local z = node("z — view/fold", entries(
    { "z", "zz: Center cursor" },
    { "t", "zt: Cursor top" },
    { "b", "zb: Cursor bottom" },
    { "a", "za: Toggle fold" },
    { "o", "zo: Open fold" },
    { "c", "zc: Close fold" },
    { "R", "zR: Open all folds" },
    { "M", "zM: Close all folds" }
  ), {})
  z.children["z"] = node("zz — center cursor", entries({ "✓", "done" }), {})

  -- <C-w> windows
  local cw = node("<C-w> — windows", entries(
    { "w", "Next window" },
    { "h", "Focus left" }, { "j", "Focus down" }, { "k", "Focus up" }, { "l", "Focus right" },
    { "s", "Split horizontal" }, { "v", "Split vertical" },
    { "c", "Close window" }, { "o", "Only window" },
    { "=", "Equalize" }
  ), {})

  -- [ ] (minimal defaults; you can expand later)
  local lbr = node("[ — previous", entries(
    { "[", "[[: Prev section" },
    { "q", "[q: Prev quickfix" },
    { "l", "[l: Prev loclist" }
  ), {})
  local rbr = node("] — next", entries(
    { "]", "]]: Next section" },
    { "q", "]q: Next quickfix" },
    { "l", "]l: Next loclist" }
  ), {})

  root.children["d"] = del
  root.children["c"] = chg
  root.children["y"] = ynk
  root.children["g"] = g
  root.children["z"] = z
  root.children["<C-w>"] = cw
  root.children["["] = lbr
  root.children["]"] = rbr

  return root
end

-- ---------- State ----------
local state = {
  enabled = true,
  tree = nil,
  cur = nil,
  seq = {},
  buf = nil,
  win = nil,
  ns = nil,
  height = 10, -- default split height
}

local function mode_ok()
  local m = vim.api.nvim_get_mode().mode
  return m == "n" or m:sub(1, 2) == "no" -- normal or operator-pending
end

local function ensure_split()
  if not state.enabled then return end

  if state.buf == nil or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = state.buf })
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = state.buf })
    vim.api.nvim_set_option_value("swapfile", false, { buf = state.buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })
    vim.api.nvim_set_option_value("filetype", "keycoach", { buf = state.buf })
  end

  -- If window exists, ensure it still shows our buffer
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    if vim.api.nvim_win_get_buf(state.win) ~= state.buf then
      vim.api.nvim_win_set_buf(state.win, state.buf)
    end
    return
  end

  -- Create a real bottom split and then return focus to previous window
  local prev = vim.api.nvim_get_current_win()
  vim.cmd(("botright %dsplit"):format(state.height))
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, state.buf)

  -- Window-local options (make it HUD-like)
  local wo = function(opt, val) vim.api.nvim_set_option_value(opt, val, { win = state.win }) end
  wo("number", false)
  wo("relativenumber", false)
  wo("signcolumn", "no")
  wo("foldcolumn", "0")
  wo("cursorline", false)
  wo("wrap", false)
  wo("list", false)
  wo("spell", false)
  wo("winfixheight", false) -- allow resizing
  wo("statusline", "")      -- keep it clean

  -- Make it visually distinct (optional)
  wo("winhl", "Normal:NormalFloat")

  -- Return focus to the original window
  if vim.api.nvim_win_is_valid(prev) then
    vim.api.nvim_set_current_win(prev)
  end
end

local function render()
  if not state.enabled then return end
  ensure_split()
  if not (state.win and vim.api.nvim_win_is_valid(state.win)) then return end

  local w = vim.api.nvim_win_get_width(state.win)

  local lines = {}
  lines[#lines + 1] = ("KeyCoach | %s"):format(state.cur.label or "")
  lines[#lines + 1] = "" -- spacer

  render_grid(lines, w, state.cur.entries or {}, 4)

  lines[#lines + 1] = ""
  lines[#lines + 1] = (#state.seq > 0) and ("Seq: " .. table.concat(state.seq, " ")) or "Seq: (root)"

  vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf })
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })
end

local function reset_root()
  state.cur = state.tree
  state.seq = {}
  render()
end

local function step(token)
  local child = state.cur.children and state.cur.children[token]

  -- Only switch menus when follow-ups exist
  if child then
    state.cur = child
    state.seq[#state.seq + 1] = token
    render()
    return
  end

  -- If we were in a submenu and hit something else, snap back to root
  if state.cur ~= state.tree then
    reset_root()
  end
end

local function on_key(raw)
  if not state.enabled then return end
  if not mode_ok() then
    reset_root()
    return
  end

  local token = vim.fn.keytrans(raw)

  if token == "<Esc>" or token == "<C-c>" then
    reset_root()
    return
  end

  step(token)
end

function M.setup(opts)
  opts = opts or {}
  state.height = opts.height or state.height
  state.tree = opts.tree or build_tree()
  state.cur = state.tree
  state.seq = {}
  state.ns = vim.api.nvim_create_namespace("KeyCoachHUDOnKey")

  ensure_split()
  render()

  vim.on_key(on_key, state.ns)

  vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter", "WinEnter", "VimResized" }, {
    callback = function()
      if state.enabled then
        ensure_split()
        render()
      end
    end,
  })

  vim.api.nvim_create_user_command("KeyCoachToggle", function()
    state.enabled = not state.enabled
    if not state.enabled then
      if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
      end
      state.win = nil
    else
      ensure_split()
      reset_root()
    end
  end, {})
end

return M

