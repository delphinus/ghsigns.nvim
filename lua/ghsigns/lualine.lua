---@class Ghsigns.Lualine
local Lualine = {}

Lualine.component = function()
  local ghsigns = require("ghsigns").ghsigns
  local colors = assert(ghsigns.opts.colors)
  local lualine_require = require "lualine_require"
  local M = lualine_require.require("lualine.component"):extend()

  function M:init(options)
    options = vim.tbl_extend("force", { on_click = Lualine.on_click }, options or {})
    M.super.init(self, options)
    self.highlights = {
      arrow = self:create_hl(colors.arrow, "arrow"),
      base = self:create_hl(colors.base, "base"),
      head = self:create_hl(colors.head, "head"),
      icon = self:create_hl(colors.icon, "icon"),
    }
  end

  function M:update_status()
    local hl = vim.iter(self.highlights):fold({}, function(a, k, v)
      a[k] = self:format_hl(v)
      return a
    end)
    local git, pr = Lualine.get_info()
    if git and git.revision and pr then
      local revision = git.revision:gsub("^origin/", "")
      return table.concat({
        hl.icon .. "",
        hl.head .. git.head,
        hl.arrow .. "←",
        ("%s%s #%d"):format(hl.base, revision, pr.number),
      }, " ")
    elseif git then
      return table.concat({
        hl.icon .. "",
        hl.head .. git.head,
      }, " ")
    end
    return ""
  end

  return M
end

---@return Ghsigns.GitInfo?
---@return Ghsigns.Pr?
Lualine.get_info = function()
  local ghsigns = require("ghsigns").ghsigns
  if not ghsigns.enabled then
    return
  end
  return ghsigns:get(vim.api.nvim_get_current_buf())
end

local wait_double_click = false

---@param clicks integer
Lualine.on_click = function(clicks)
  if clicks > 2 then
    return
  end
  local _, pr = Lualine.get_info()
  if not pr or not pr.url then
    vim.notify "No PR information available for this buffer"
    return
  end
  if clicks == 1 then
    wait_double_click = true
    assert(vim.uv.new_timer()):start(300, 0, function()
      if wait_double_click then
        wait_double_click = false
        vim.schedule_wrap(Lualine.show_pr_info)(pr)
      end
    end)
  elseif clicks == 2 then
    wait_double_click = false
    vim.notify("opening PR: " .. pr.url)
    vim.ui.open(pr.url)
  end
end

local FloatWin = require "ghsigns.float_win"
local float_win = FloatWin.new()

local cb = require "ghsigns.content_builder"
local ContentBuilder = cb.ContentBuilder
local prepare_pr_data = cb.prepare_pr_data

--- Build PR content for display (extracted for testability)
---@param pr Ghsigns.Pr
---@return Ghsigns.PrContent
Lualine.build_pr_content = function(pr)
  local b = ContentBuilder.new()
  local p = prepare_pr_data(pr)
  local title_line, title_text = b:build_header(p)
  b:build_body(p)
  local close_line_idx = b:build_footer()
  local result = b:result()
  result.title_line = title_line
  result.title_text = title_text
  result.close_line_idx = close_line_idx
  return result
end

--- Apply highlights, link extmarks, and title extmark to a buffer
---@param buf integer
---@param ns integer
---@param content Ghsigns.PrContent
---@param pr_url? string
local function apply_content_to_buffer(buf, ns, content, pr_url)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content.lines)

  for _, hl_info in ipairs(content.highlights) do
    local line_text = content.lines[hl_info.line + 1]
    if line_text then
      for _, group in ipairs(hl_info.groups) do
        local end_col = group.end_col
        if end_col == -1 or end_col > #line_text then
          end_col = #line_text
        end
        vim.api.nvim_buf_set_extmark(buf, ns, hl_info.line, group.col, {
          end_col = end_col,
          hl_group = group.hl,
        })
      end
    end
  end

  for _, link in ipairs(content.link_metadata) do
    vim.api.nvim_buf_set_extmark(buf, ns, link.line, link.col_start, {
      end_col = link.col_end,
      hl_group = "Underlined",
      url = link.url,
    })
  end

  if pr_url then
    vim.api.nvim_buf_set_extmark(buf, ns, content.title_line, 0, {
      end_col = #content.title_text,
      url = pr_url,
    })
  end
end

--- Calculate window size and position, open the floating window
---@param buf integer
---@param content Ghsigns.PrContent
---@return integer win
local function open_float_window(buf, content)
  local width = 0
  for _, line in ipairs(content.lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width + 2, math.floor(vim.o.columns * 0.8))
  local height = math.min(#content.lines, math.floor(vim.o.lines * 0.8))

  local mouse_pos = vim.fn.getmousepos()
  local row = mouse_pos.screenrow
  local col = mouse_pos.screencol

  local total_height = height + 2
  local max_row = vim.o.lines - vim.o.cmdheight - 1

  if row + total_height > max_row then
    row = math.max(0, max_row - total_height)
  end
  if col + width > vim.o.columns then
    col = math.max(0, vim.o.columns - width)
  end

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " PR Info ",
    title_pos = "center",
  })
  float_win:setup(win)

  vim.api.nvim_set_option_value("wrap", true, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  vim.wo[win].statusline = " "
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  return win
end

--- Set up keymaps and mouse click handlers for the floating window
---@param buf integer
---@param ns integer
---@param win integer
---@param content Ghsigns.PrContent
local function setup_float_keymaps(buf, ns, win, content)
  local close_keys = { "q", "<Esc>", "<CR>" }
  for _, key in ipairs(close_keys) do
    vim.api.nvim_buf_set_keymap(buf, "n", key, ":close<CR>", { noremap = true, silent = true })
  end

  vim.keymap.set("n", "<LeftRelease>", function()
    local mouse = vim.fn.getmousepos()
    if mouse.winid == win then
      if mouse.line == content.close_line_idx + 1 then
        float_win:close_if_valid()
        return
      end

      local click_line = mouse.line - 1
      local click_col = mouse.column - 1
      local extmarks =
        vim.api.nvim_buf_get_extmarks(buf, ns, { click_line, 0 }, { click_line + 1, 0 }, { details = true })
      for _, mark in ipairs(extmarks) do
        local _, _, start_col, details = unpack(mark)
        if details.url then
          local end_col = details.end_col or (start_col + 1)
          if click_col >= start_col and click_col < end_col then
            vim.notify("Opening: " .. details.url, vim.log.levels.INFO)
            vim.ui.open(details.url)
            return
          end
        end
      end
    end
  end, { buffer = buf, noremap = true, silent = true })
end

--- @param pr Ghsigns.Pr
Lualine.show_pr_info = function(pr)
  if float_win:close_if_valid() then
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local ns = vim.api.nvim_create_namespace "ghsigns_pr_info"

  local title_hl = vim.api.nvim_get_hl(0, { name = "Title" })
  title_hl.underline = true
  vim.api.nvim_set_hl(0, "GhsignsPrTitle", title_hl)

  local content = Lualine.build_pr_content(pr)
  apply_content_to_buffer(buf, ns, content, pr.url)
  local win = open_float_window(buf, content)
  setup_float_keymaps(buf, ns, win, content)
end

return Lualine
