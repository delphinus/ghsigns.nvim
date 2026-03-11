local FloatWin = require "ghsigns.float_win"
local cb = require "ghsigns.content_builder"
local display_utils = require "ghsigns.display_utils"
local ContentBuilder = cb.ContentBuilder

local float_win = FloatWin.new "ghsigns_md_preview_float"

local MdPreview = {}

--- Build rendered content from markdown lines (extracted for testability)
---@param lines string[]
---@param opts? { max_width?: integer }
---@return Ghsigns.PrContent
MdPreview.build_content = function(lines, opts)
  opts = opts or {}
  local max_width = opts.max_width or 80

  local b = ContentBuilder.new()

  local in_code_block = false
  local code_block_lang = nil
  local code_block_start = nil
  local prev_was_heading = false
  local prev_was_blank = false
  local table_buf = {}
  local lines_shown = 0

  --- Flush accumulated table lines
  local function flush_table()
    if #table_buf > 0 then
      b:add_table(table_buf, "  ", max_width)
      table_buf = {}
    end
  end

  for _, line in ipairs(lines) do
    local is_blank = line:match "^%s*$" ~= nil
    local is_heading = (not in_code_block) and line:match "^#+%s+" ~= nil
    local is_table_line = (not in_code_block) and line:match "^%s*|" ~= nil

    -- Accumulate table lines
    if is_table_line then
      table.insert(table_buf, line)
      goto continue
    end

    -- Flush table buffer when a non-table line is encountered
    if #table_buf > 0 then
      flush_table()
    end

    -- Skip blank lines immediately after headings (outside code blocks)
    if not in_code_block and is_blank and prev_was_heading then
      prev_was_blank = true
      goto continue
    end

    -- Auto-insert blank line before headings if not already preceded by one
    if not in_code_block and is_heading and lines_shown > 0 and not prev_was_blank then
      b:add_line "  "
      lines_shown = lines_shown + 1
    end

    local lines_before = #b.lines

    if line:match "^```" then
      if not in_code_block then
        in_code_block = true
        code_block_lang = line:match "^```(%S+)" or nil
        code_block_start = #b.lines
      else
        if code_block_lang and code_block_start < #b.lines then
          table.insert(b.code_blocks, {
            language = code_block_lang,
            start_line = code_block_start,
            end_line = #b.lines - 1,
          })
        end
        in_code_block = false
        code_block_lang = nil
      end
    elseif in_code_block then
      local indented = "  " .. line
      local display_width = vim.fn.strdisplaywidth(indented)
      if display_width > max_width then
        local target = max_width - 1
        local current_width = 0
        local byte_pos = 0
        for char in indented:gmatch "[%z\1-\127\194-\253][\128-\191]*" do
          local char_width = vim.fn.strdisplaywidth(char)
          if current_width + char_width > target then
            break
          end
          current_width = current_width + char_width
          byte_pos = byte_pos + #char
        end
        b:add_line(indented:sub(1, byte_pos) .. "…", { { col = 0, end_col = -1, hl = "String" } })
      else
        b:add_line(indented, { { col = 0, end_col = -1, hl = "String" } })
      end
    else
      b:add_markdown_line(line, "  ", max_width)
    end

    local lines_added = #b.lines - lines_before
    lines_shown = lines_shown + lines_added

    prev_was_heading = is_heading
    prev_was_blank = is_blank

    ::continue::
  end

  -- Flush any remaining table lines
  flush_table()

  return b:result()
end

--- Show a floating window previewing the current buffer's markdown content
---@param opts? { max_width?: integer }
MdPreview.show = function(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local name = vim.api.nvim_buf_get_name(bufnr)

  if ft ~= "markdown" and not name:match "%.md$" and not name:match "%.markdown$" then
    vim.notify("ghsigns: current buffer is not a Markdown file", vim.log.levels.WARN)
    return
  end

  if float_win:close_if_valid() then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = MdPreview.build_content(lines, opts)

  local buf = vim.api.nvim_create_buf(false, true)
  local ns = vim.api.nvim_create_namespace "ghsigns_md_preview"

  -- Obsidian ==highlight== marker
  vim.api.nvim_set_hl(0, "GhsignsHighlight", { bg = "#3b3600", fg = "#ffec80", default = true })

  display_utils.apply_content_to_buffer(buf, ns, content)
  local win = display_utils.open_float_window(buf, content, float_win, {
    title = " Markdown Preview ",
    position = "center",
    enter = true,
  })
  display_utils.setup_float_keymaps(buf, ns, win, content, float_win)
end

return MdPreview
