local api = vim.api
local fn = vim.fn

--- @class Scratchpad
--- @field id number?
--- @field title string?
--- @field display_name string?
--- @field bufnr number
--- @field window number
--- @field ui_opts table<string, any>?
local Scratchpad = {}

function Scratchpad:new(opts)
  opts = opts or {}
  opts.title = opts.title or "-- Scratchpad!"
  opts.display_name = opts.display_name or "*scratch*"
  self.__index = self
  return setmetatable(opts, self)
end

function Scratchpad:toggle()
  if self:is_open() then
    self:close()
  else
    self:open()
  end
  return self
end

function Scratchpad:is_open()
  if not self.window then return false end
  local win_type = fn.win_gettype(self.window)
  -- empty string window type corresponds to a normal window
  local win_open = win_type == "" or win_type == "popup"
  return win_open and api.nvim_win_get_buf(self.window) == self.bufnr
end

function Scratchpad:open()
  local valid_buf = self.bufnr and api.nvim_buf_is_valid(self.bufnr)
  local buf = valid_buf and self.bufnr or api.nvim_create_buf(false, false)
  local win = api.nvim_open_win(buf, true, self:_get_float_config(true))

  self.window, self.bufnr = win, buf
  api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  api.nvim_set_option_value("sidescrolloff", 0, { scope = "local", win = win })
end

function Scratchpad:close()
  if self.window and api.nvim_win_is_valid(self.window) then
    api.nvim_win_close(self.window, true)
    self.window = nil
  end
  vim.cmd("stopinsert!")
end

function Scratchpad:_resolve_size(size)
  if not size then
    return
  elseif type(size) == "number" then
    return size
  end
end

local curved = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }

--- @private
--- @param opening boolean
--- copied from https://github.com/akinsho/toggleterm.nvim/blob/193786e0371e3286d3bc9aa0079da1cd41beaa62/lua/toggleterm/ui.lua#L272
function Scratchpad:_get_float_config(opening)
  local opts = self.ui_opts or {}
  local border = opts.border == "curved" and curved or opts.border or "single"

  local width = math.ceil(math.min(vim.o.columns, math.max(80, vim.o.columns - 20)))
  local height = math.ceil(math.min(vim.o.lines, math.max(20, vim.o.lines - 10)))

  width = vim.F.if_nil(self:_resolve_size(opts.width), width)
  height = vim.F.if_nil(self:_resolve_size(opts.height), height)

  local row = math.ceil(vim.o.lines - height) * 0.5 - 1
  local col = math.ceil(vim.o.columns - width) * 0.5 - 1

  row = vim.F.if_nil(self._resolve_size(opts.row), row)
  col = vim.F.if_nil(self._resolve_size(opts.col), col)

  local version = vim.version()

  local ui_config = {
    row = row,
    col = col,
    relative = opts.relative or "editor",
    style = nil,
    width = width,
    height = height,
    border = opening and border or nil,
    zindex = opts.zindex or nil,
  }
  if version.major > 0 or version.minor >= 9 then
    ui_config.title_pos = self.display_name and opts.title_pos or nil
    ui_config.title = self.display_name -- TODO should I use title
  end
  return ui_config
end

-- @type Notepad
local current = {}

local toggle_command = function(opts)
  if not current.bufnr then
    current = Scratchpad:new(opts)
  end
  current:toggle()
end

local function setup(opts)
  opts = opts or {}

  vim.keymap.set("n", opts.lhs or "<F3>", function() toggle_command(opts) end, { desc = "scratchpad" })
end

return { setup = setup }
