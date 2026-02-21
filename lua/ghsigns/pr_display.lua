local FloatWin = require "ghsigns.float_win"
local cb = require "ghsigns.content_builder"
local ContentBuilder = cb.ContentBuilder
local prepare_pr_data = cb.prepare_pr_data

local float_win = FloatWin.new()

local PrDisplay = {}

--- Build PR content for display (extracted for testability)
---@param pr Ghsigns.Pr
---@return Ghsigns.PrContent
PrDisplay.build_pr_content = function(pr)
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
PrDisplay.show_pr_info = function(pr)
  if float_win:close_if_valid() then
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local ns = vim.api.nvim_create_namespace "ghsigns_pr_info"

  local title_hl = vim.api.nvim_get_hl(0, { name = "Title" })
  title_hl.underline = true
  vim.api.nvim_set_hl(0, "GhsignsPrTitle", title_hl)

  local content = PrDisplay.build_pr_content(pr)
  apply_content_to_buffer(buf, ns, content, pr.url)
  local win = open_float_window(buf, content)
  setup_float_keymaps(buf, ns, win, content)
end

return PrDisplay
