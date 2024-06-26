local api = vim.api
local fn = vim.fn

--- @class Scratchpad
--- @field id number?
--- @field title string?
--- @field title_pos string?
--- @field file_ext string?
--- @field file_name string
--- @field notes_dir string?
--- @field bufnr number
--- @field window number
--- @field ui_opts table<string, any>?
local Scratchpad = {}

function Scratchpad:path(opts)
  if opts.notes_dir then
    local first_char = string.sub(opts.notes_dir, 1, 1)
    if first_char == "~" then
      return vim.fn.expand(opts.notes_dir)
    elseif first_char == "/" then
      return opts.notes_dir
    else
      return vim.fn.expand("~") .. opts.notes_dir
    end
  else
    return vim.fn.stdpath("data") .. "/scratch_notes"
  end
end

function Scratchpad:name_with_path(opts)
  local notes_dir = self:path(opts)
  local cwd = vim.fn.getcwd()
  if not vim.fn.isdirectory(notes_dir) ~= 0 then
    -- TODO check if error
    vim.fn.mkdir(notes_dir, "p")
  end
  -- TODO keep a map of names maybe from the hash of cwd to file names to avoid collitions
  local file_ext = opts.file_ext or "md"
  local workin_dir = vim.fn.fnamemodify(cwd, ":t")
  local file_name = workin_dir .. "-notes" -- TODO configure in settings if we want a sufix
  return notes_dir .. "/" .. file_name .. "." .. file_ext
end

function Scratchpad:new(opts)
  opts = opts or {}
  opts.title = opts.title or "*scratchpad*"
  -- TODO display in window title the name of the file ? (no extension)
  opts.file_name = self:name_with_path(opts)
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
  local win = api.nvim_open_win(buf, true, self:_get_float_config())
  self.window, self.bufnr = win, buf
  vim.cmd("edit " .. self.file_name)
  api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  api.nvim_set_option_value("sidescrolloff", 0, { scope = "local", win = win })
end

function Scratchpad:close()
  if self.bufnr and api.nvim_buf_get_option(self.bufnr, "modified") then
    vim.cmd("w " .. self.file_name)
  end
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

--- copied from https://github.com/akinsho/toggleterm.nvim/blob/193786e0371e3286d3bc9aa0079da1cd41beaa62/lua/toggleterm/ui.lua#L272
--- @private
function Scratchpad:_get_float_config()
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
    border = border or nil,
    zindex = opts.zindex or nil,
  }
  if version.major > 0 or version.minor >= 9 then
    ui_config.title_pos = self.title and self.title_pos or nil
    ui_config.title = self.title
  end
  return ui_config
end

-- @type Notepad
local current = {}

local function setup(opts)
  current = Scratchpad:new(opts)

  api.nvim_create_user_command(
    "ScratchpadToggle",
    function() current:toggle() end,
    {}
  )
end

return { setup = setup }
